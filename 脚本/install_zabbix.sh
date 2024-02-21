#!/bin/bash
#scripts for zabbix install
ZabbixAgentConfigureParameter='--prefix=/usr/local/zabbix --enable-agent --with-libcurl   --with-openssl '
ZabbixServerConfigureParameter='--prefix=/usr/local/zabbix --enable-server --with-net-snmp --with-libcurl  --with-mysql=/usr/bin/mysql_config  --with-openssl'
ZabbixProxyConfigureParameter='--prefix=/usr/local/zabbix --enable-proxy --with-net-snmp --with-libcurl  --with-mysql=/usr/bin/mysql_config  --with-openssl'
ZabbixServerAgentConfigureParameter='--prefix=/usr/local/zabbix --enable-server --enable-agent --with-net-snmp --with-libcurl  --with-mysql=/usr/bin/mysql_config  --with-openssl'
ZabbixProxyAgentConfigureParameter='--prefix=/usr/local/zabbix --enable-agent --enable-proxy --with-net-snmp --with-libcurl  --with-mysql=/usr/bin/mysql_config  --with-openssl'
#ZabbixConfigureParameter

#脚本所在目录
cd "$(dirname $0)"
ScriptsDir=$(pwd)
#ScriptsName
ScriptsName=$(basename $0)

#逻辑判断
ZabbixSourceCodeFile="$1"

function Main() {
if [ "${USER}" != 'root' ];then
	echo "ERROR: The run script user must be root"
	exit 1
fi

if [ "${ZabbixSourceCodeFile}" == "add_zabbix_config" ];then
	add_zabbix_config
	exit
elif [ "${ZabbixSourceCodeFile}" == "--help" ];then
	Help
	exit
fi

#逻辑判断
[ -z ${ZabbixSourceCodeFile} ] && exit 1
[ ! -f ${ZabbixSourceCodeFile} ] && {
        echo "ERROR: zabbix file ${ZabbixSourceCodeFile} not found"
        exit 1
}


echo "Example: "
echo -e "\033[32m Agent Configure:\033[0m ${ZabbixAgentConfigureParameter}"
echo -e "\033[32m Proxy Configure:\033[0m ${ZabbixProxyConfigureParameter}"
echo -e "\033[32m Server Configure:\033[0m ${ZabbixServerConfigureParameter}"
echo -e "\033[32m Proxy And Agent Configure:\033[0m ${ZabbixProxyAgentConfigureParameter}"
echo -e "\033[32m Server And Agent Configure:\033[0m ${ZabbixServerAgentConfigureParameter}"
echo ""
while true
do
	read -p "Please Input Zabbix Configure Parameter: " "ZabbixConfigureParameter"
	if [ -z "${ZabbixConfigureParameter}" ];then
		continue
	fi
	break
done
#处理文件
if [ ! -f ${ZabbixSourceCodeFile} ];then
        echo "ERROR: ${ZabbixSourceCodeFile} not exit !"
        exit 1
fi

ZabbixSourceCodeDir="$(dirname ${ZabbixSourceCodeFile})"
#切换到源码压缩文件目录
cd ${ZabbixSourceCodeDir} || {
        echo "ERROR: cd ${ZabbixSourceCodeDir}  fail"
        exit 1
}

ZabbixSourceCodeName="$(basename ${ZabbixSourceCodeFile})"
ZabbixSourceDirName=$(tar -tvf ${ZabbixSourceCodeName} | head -1 | sed -n 's@\(.*\)\(zabbix.*\)@\2@p')
#进行解压
tar -zxf ${ZabbixSourceCodeName} || {
        echo "ERROR: tar -zxf ${ZabbixSourceCodeName} fail"
        exit 1
}
#切换到源码目录
cd ${ZabbixSourceDirName} || {
        echo "ERROR: cd ${ZabbixSourceDirName}  fail"
        exit 1
}

#进行安装
install_zabbix
#解压配置模板
unzip_zabbix_config
#更新配置
cd ${ScriptsDir}
update_zabbix_configure
#显示
display_zabbix_configure
}


function install_zabbix() {
	#安装依赖
	echo -e "\033[33;1m Start install dependent application \033[0m"
	yum install gcc gcc-c++ openssl openssl-devel curl-devel tls-devel gnutls-devel fnutls-devel
	#配置
	echo -e "\033[33;1m Start Configure \033[0m"
	sleep 3
	./configure ${ZabbixConfigureParameter} || {
		echo "ERROR: ./configure ${ZabbixConfigureParameter} fail"
		exit 1
	}
	#进行编译
	echo -e "\033[33;1m Start Make \033[0m"
        sleep 3
	make || {
		echo "ERROR: make fail"
		exit 1
	}
	#进行安装
	echo -e "\033[33;1m Start Install \033[0m"
        sleep 3
	make install || {
		echo "ERROR: make install fail"
		exit 1
	}

}

function update_zabbix_configure() {
	InstallStatus='0'
	ZabbixInstallDir="$(echo "${ZabbixConfigureParameter}" | sed -n 's@[[:space:]]@\n@gp' | sed -n 's@\(--prefix=\)\(.*\)@\2@p')"
	mkdir ${ZabbixInstallDir}/etc/psk -p
	echo -e "\033[34,1m Cannot contain @ character \033[0m"
	#Server
	if [ -f ${ZabbixInstallDir}/etc/zabbix_server.conf ];then
                echo -e "\033[33;1m Config And Update zabbix_server.conf \033[0m"
		echo "Please Input Parameter For Zabbix Server (zabbix_server.conf)"
		read -p 'MySQL server address(Default localhost): ' "ServerDBHost"
		[ -z "${ServerDBHost}" ] && ServerDBHost='localhost'
		read -p 'MySQL server DBName(Default zabbix): ' "ServerDBName"
		[ -z "${ServerDBName}" ] && ServerDBName='zabbix'
		read -p 'MySQL server DBUser(Default zabbix): ' "ServerDBUser"
		[ -z "${ServerDBUser}" ] && ServerDBUser='zabbix'
		read -p 'MySQL server DBPassword(Default zabbix): ' "ServerDBPassword"
		[ -z "${ServerDBPassword}" ] && ServerDBPassword='zabbix'
		while true
		do
			read -p 'MySQL server DBPort(Default 3306): ' "ServerDBPort"
			[ -z "${ServerDBPort}" ] && {
				ServerDBPort='3306'
				break
			}
			[ "${ServerDBPort}" -gt 0 ] >/dev/null 2>&1 && break
		done

		#开始更新配置
		sed -i 's@\(^DBHost=\)\(.*\)@\1'"${ServerDBHost}"'@' ./zabbix_config/zabbix_server.conf
		sed -i 's@\(^DBName=\)\(.*\)@\1'"${ServerDBName}"'@' ./zabbix_config/zabbix_server.conf
		sed -i 's@\(^DBUser=\)\(.*\)@\1'"${ServerDBUser}"'@' ./zabbix_config/zabbix_server.conf
		sed -i 's@\(^DBPassword=\)\(.*\)@\1'"${ServerDBPassword}"'@' ./zabbix_config/zabbix_server.conf
		sed -i 's@\(^DBPort=\)\(.*\)@\1'"${ServerDBPort}"'@' ./zabbix_config/zabbix_server.conf

		#生成连接密钥
		openssl rand -hex 32 > ${ZabbixInstallDir}/etc/psk/zabbix_server.psk

		#安装zabbix相关管理脚本
		#cp -r ${ZabbixSourceCodeDir}/misc/init.d/fedora/core/zabbix_server /etc/rc.d/init.d/zabbix_server && chmod 755 /etc/rc.d/init.d/zabbix_server
		#sed -i 's@\(BASEDIR=\)\(.*\)@\1'"${ZabbixInstallDir}"@'' /etc/rc.d/init.d/zabbix_server
		#sed -i 's@\(PIDFILE=\)\(.*\)@\1/var/run/zabbix@' /etc/rc.d/init.d/zabbix_server
		#chkconfig --add zabbix_server

		ServerConfiureUpdate='True'
		InstallStatus=$((InstallStatus+1))
        fi

	#Proxy
	if [ -f ${ZabbixInstallDir}/etc/zabbix_proxy.conf ];then
		echo -e "\033[33;1m Config And Update zabbix_proxy.conf \033[0m"
		echo "Please Input Parameter For Zabbix Proxy (zabbix_proxy.conf)"
                read -p 'MySQL server address(Default localhost): ' "ProxyDBHost"
                [ -z "${ProxyDBHost}" ] && ProxyDBHost='localhost'
                read -p 'MySQL server DBName(Default zabbix_proxy): ' "ProxyDBName"
                [ -z "${ProxyDBName}" ] && ProxyDBName='zabbix_proxy'
                read -p 'MySQL server DBUser(Default zabbix): ' "ProxyDBUser"
                [ -z "${ProxyDBUser}" ] && ProxyDBUser='zabbix'
                read -p 'MySQL server DBPassword(Default zabbix): ' "ProxyDBPassword"
                [ -z "${ProxyDBPassword}" ] && ProxyDBPassword='zabbix'
                while true
                do
                        read -p 'MySQL server DBPort(Default 3306): ' "ProxyDBPort"
                        [ -z "${ProxyDBPort}" ] && {
                                ProxyDBPort='3306'
                                break
                        }
                        [ "${ProxyDBPort}" -gt 0 ] >/dev/null 2>&1 && break
                done

		while true
		do
			read -p 'zabbix server IP address: ' "ProxyServer"
			if [[ "${ProxyServer}" =~ ^[1-2]{0,1}[0-9]{0,2}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];then
				break
			fi
			echo "IP address error"
		done

		while true
		do
			read -p 'zabbix proxy Hostname(example: Cokutau Zabbix Proxy): ' "ProxyHostname"
			[ ! -z "${ProxyHostname}" ] && break
		done

		while true
		do
			read -p 'zabbix proxy PSK TLSPSKIdentity(example: Cokutau PSK Zabbix Proxy): ' "ProxyTLSPSKIdentity"
			[ ! -z "${ProxyTLSPSKIdentity}" ] && break
		done

                #开始更新配置
                sed -i 's@\(^DBHost=\)\(.*\)@\1'"${ProxyDBHost}"'@' ./zabbix_config/zabbix_proxy.conf
                sed -i 's@\(^DBName=\)\(.*\)@\1'"${ProxyDBName}"'@' ./zabbix_config/zabbix_proxy.conf
                sed -i 's@\(^DBUser=\)\(.*\)@\1'"${ProxyDBUser}"'@' ./zabbix_config/zabbix_proxy.conf
                sed -i 's@\(^DBPassword=\)\(.*\)@\1'"${ProxyDBPassword}"'@' ./zabbix_config/zabbix_proxy.conf
                sed -i 's@\(^DBPort=\)\(.*\)@\1'"${ProxyDBPort}"'@' ./zabbix_config/zabbix_proxy.conf

		sed -i 's@\(^Server=\)\(.*\)@\1'"${ProxyServer}"'@' ./zabbix_config/zabbix_proxy.conf
		sed -i 's@\(^Hostname=\)\(.*\)@\1'"${ProxyHostname}"'@' ./zabbix_config/zabbix_proxy.conf
		sed -i 's@\(^TLSPSKIdentity=\)\(.*\)@\1'"${ProxyTLSPSKIdentity}"'@' ./zabbix_config/zabbix_proxy.conf

		#生成连接密钥
                openssl rand -hex 32 > ${ZabbixInstallDir}/etc/psk/zabbix_proxy.psk

		ProxyConfiureUpdate='True'
		InstallStatus=$((InstallStatus+1))
	fi

	#Agentd
	if [ -f ${ZabbixInstallDir}/etc/zabbix_agentd.conf ];then
		echo -e "\033[33;1m Config And Update zabbix_agentd.conf \033[0m"
		echo "Please Input Parameter For Zabbix Agent (zabbix_agentd.conf)"

                while true
                do
                        read -p 'zabbix server or proxy IP address: ' "AgentServer"
                        if [[ "${AgentServer}" =~ ^[1-2]{0,1}[0-9]{0,2}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];then
                                break
                        fi
                        echo "IP address error"
                done

                while true
                do
                        read -p 'zabbix agent Hostname(example: Cokutau Zabbix Agent): ' "AgentHostname"
                        [ ! -z "${AgentHostname}" ] && break
                done

                while true
                do
                        read -p 'zabbix agent PSK TLSPSKIdentity(example: Cokutau PSK Zabbix Agent): ' "AgentTLSPSKIdentity"
                        [ ! -z "${AgentTLSPSKIdentity}" ] && break
                done

		#开始更新配置
                sed -i 's@\(^Server=\)\(.*\)@\1'"${AgentServer}"'@' ./zabbix_config/zabbix_agentd.conf
                sed -i 's@\(^Hostname=\)\(.*\)@\1'"${AgentHostname}"'@' ./zabbix_config/zabbix_agentd.conf
                sed -i 's@\(^TLSPSKIdentity=\)\(.*\)@\1'"${AgentTLSPSKIdentity}"'@' ./zabbix_config/zabbix_agentd.conf

		#生成连接密钥
                openssl rand -hex 32 > ${ZabbixInstallDir}/etc/psk/zabbix_agentd.psk

		AgentConfiureUpdate='True'
		InstallStatus=$((InstallStatus+1))
	fi


	#添加用户
	id zabbix >/dev/null 2>&1
	ReturnCode="$?"
	if [ ${ReturnCode} -eq '0' ];then
		echo "WARR: User zabbix exit "
		sleep 3
	else
		groupadd -r zabbix || {
			echo "ERROR: groupadd -r zabbix fail"
			exit 1
		}
		useradd -r -g zabbix zabbix -M -s /bin/false || {
			echo "ERROR: useradd -r -g zabbix zabbix -M -s /bin/false fail"
			exit 1
		}
	fi

	#创建相关目录并且授权
	mkdir -p /var/run/zabbix && chown zabbix.zabbix /var/run/zabbix -R
	mkdir -p /var/log/zabbix && chown zabbix.zabbix /var/log/zabbix -R

	return ${InstallStatus}

	#把相关配置复制到目标目录
}



function display_zabbix_configure() {
	[ "${InstallStatus}" -gt 0 ] || {
		echo -e "\033[31m Install Zabbix Fail \033[0m"
		exit 1
	}

	clear
	echo -e "\033[32m Install Zabbix Success: \033[0m"
	ServerDisplayZabbixConfigure=('DBHost=' 'DBName=' 'DBUser=' 'DBPassword=' 'DBPort=' 'LogFile=' 'PidFile=')
	ProxyDisplayZabbixConfigure=('ProxyMode=' 'DBHost=' 'DBName=' 'DBUser=' 'DBPassword=' 'DBPort=' 'Server=' 'Hostname=' 'TLSConnect=' 'TLSAccept=' 'TLSPSKIdentity=' 'TLSPSKFile=' 'LogFile=' 'PidFile=')
	AgentDisplayZabbixConfigure=('Server=' 'Hostname=' 'ListenPort=' 'TLSConnect=' 'TLSAccept=' 'TLSPSKIdentity=' 'TLSPSKFile=' 'PidFile=' 'LogFile=')
        #打印出来
	#Server
        if [ "${ServerConfiureUpdate}" = 'True' ];then
		cp -f ./zabbix_config/zabbix_server.conf ${ZabbixInstallDir}/etc/zabbix_server.conf
                echo -e "\n Zabbix Server(zabbix_server.config) configure :"
                for ServerConfigure in "${ServerDisplayZabbixConfigure[@]}" 
                do
			sed -n '/^'${ServerConfigure}'/p' ./zabbix_config/zabbix_server.conf
                        #echo "$ServerConfigure"
                done
        fi

	#Proxy
        if [ "${ProxyConfiureUpdate}" = 'True' ];then
		cp -f ./zabbix_config/zabbix_proxy.conf ${ZabbixInstallDir}/etc/zabbix_proxy.conf
                echo -e "\n Zabbix Proxy(zabbix_proxy.config) configure :"
		for ProxyConfigure in "${ProxyDisplayZabbixConfigure[@]}"
		do
			sed -n '/^'${ProxyConfigure}'/p' ./zabbix_config/zabbix_proxy.conf
			#echo "${ProxyConfigure}"
		done
        fi

	#Agent
        if [ "${AgentConfiureUpdate}" = 'True' ];then
		cp -f ./zabbix_config/zabbix_agentd.conf ${ZabbixInstallDir}/etc/zabbix_agentd.conf
                echo -e "\n Zabbix Agent(zabbix_agentd.config) configure :"
		for AgentConfigure in "${AgentDisplayZabbixConfigure[@]}"
		do
			sed -n '/^'${AgentConfigure}'/p' ./zabbix_config/zabbix_agentd.conf
			#echo "${AgentConfigure}"
		done
        fi

	#清理配置
	#rm -rf ./zabbix_config

}


function unzip_zabbix_config() {
	cd ${ScriptsDir} || exit
	rm -rf zabbix_config
	ARCHIVE=$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' "${ScriptsName}")
	tail -n+$ARCHIVE "${ScriptsName}" | tar -xzvm -C ${ScriptsDir} > /dev/null 2>&1 3>&1
	if [ $? == 0 ];then
	        sleep 1
	else
	        echo "ERROR: unzip zabbix_config fail"
		exit 1
	fi
}

function add_zabbix_config() {
	cd ${ScriptsDir} || exit
	ARCHIVE=$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' "${ScriptsName}")
	sed -i ''${ARCHIVE}',$d' ${ScriptsDir}/${ScriptsName}
	[ ! -d zabbix_config ] && {
		echo "ERROR: ${ScriptsDir}/zabbix_config not exit"
		exit 1
	}
	tar  -zcvm zabbix_config >> ${ScriptsName}
}

function Help() {
	echo "$0 /tmp/zabbix-XXX.tar.gz	跟特定zabbix源码路径表示安装"
	echo "$0 add_zabbix_config	表示进行添加zabbix配置模板到脚本"
}

Main



exit 0
#This line must be the last line of the file
__ARCHIVE_BELOW__
� v�0_ �=�[�H��+�=�~G�3�6Yn<w��7�x���nvnO��XY��x������%ْ	IȬ4�}1V?�����U�_��ȹ����&���W�i�s��ҿ�d��ϭ�a���4�����o��+��8��OFV��W��G�ڕ��B�_����<���~�s������j���{�v�ڵz���W����=���Ů�N���	&�+r|�M����?S0�̶���6���nx�f~���AÙ�g��8����	��M�h~��ww�'Xxk����=쇳�g���lx|y|qv}vyŶ�uao�8�;w{C?�6�6�l�Q`���ě[ ���V��#��������#�j�v;���!|w�'V�FG���V��m��^�q0�!L)>���Y��0�����n��c���dƭd�~C��z1�8ל����Cv7�@q׿a3�Һ��,��.p"$@��x���1���4��hE~G�B9���h�s�į�V`�x��8�>|	�D}`#~�8*CHB�Ǚr8�<�d�A���D;ًm���)(�����ԧ�[+�ĥLˈ6�HTWίمu����O�O���㱋 �FHb;�5�/�8����.�#�+9����gp]
@?�r�|ߜ�[��`�����$D#+(�e\�<	���|� bro���C�㌁�����C��6��A e~߁����Aq��0hD ��L�`;�)�BQ�k�@�.�|�k;�,����YM��#)���Cǖ,�9�Ni�KOv��^1��;��/^�!
�S+�`�8��ߴ����d�,�k����/AP�!��{���ùف���V8 ���`7W�&`�'d1@J�(�_�$0���_�+ ������e#�Lw��z��ho�TĜ�/�V�� hP�97����u��j,.�_~+��j<�3w}@���8�ШM�T&�V2n?;b��V!�c��((Ua���̉�����%n�����kP���Ğ��I?�6�|�&�AuE�S%�J��BUj�ߏf���"���î9܅�O�F ��#F���b5q�Э�^����	{�l��Z�N��1j�O:~}rv�ʪ��(����� e��x6��"i�]��= �x��Q,���m��i6u��Ӏ�S �`x1Xl�@`�r3�� ���z��ST����;N����3����\B���O����=r�~�@\���,F	5P�q/�&v��!ƅ^8��G�F�y���x5��"�]C��"J�pCud�x��F<0�3�-��,�@}������KH�߀Ŀ�%GY9�2Cr�D�s�Z(/(���qPw8í���/1��'�J��a�Фx7*���"V�*o���!��EΖ��ݩ�} IUh�}	0�n���
�yu}=\Gh`��`�|�R�ڙU�}jJ�O�v���[l�T���@����7�d4��8�Mü�܅`D' ���A��х��}q�i)���+s�
ı��'�˗� �t�,0(�"~g-�rM}�g !Q��M���&$5oD����%vP�����*+��(��@J������"��|n��Wo��NGa�v�b�uv�N��Im�B����}�[�W���ہ�S8�B[��fa�_"�po���ʿ�0@"���q]��P��.�_؆��?�`_2�@��S����{Y"f ��
�`�8��� �%��l����;T��JFJ$dc|��p�h	�5�p��8x�YAS*�P�ˎh���ku�A��.���v���n��"���/��CY�c�K�Laa��h��j�a���,'�&�9(.L$s�J�{�xM$DyE��b(�Ƹ�3p�,�3y܉����,�¾d��.��$��X�4��[�X!��q`׿|��t�h�<����0���p����=��@i�D8��H1�-K�i+��RG�%+pD̘���w�3���uf�a�Z����E��ԏ][*�G�.v�Y��#p��3������	��I���9����S	��G�m�ߵڇ�mF����s��m����	�P�K,��� 7_!�]�ЈF �yK!�8Hϥ1Nbd$��3�|�?��HFC�ێ8�������=(���2�¥��ąА�.ߓc�<^�]���qc�3	������tu�_�9�3�J `���4a��8�Ӏ	.����#��1�7�xS�Jc�ly�0�����l
~Rwx����2�1��1�M�9��X��BL�z�x0���)\t#�H<�#��dċ�k�F;����%_�֢�907N1E3;�º�x�p���O1�o4�Cde�o"+|~C�d�(W�(�� ﴡ��{GS�U��s��[ˍ�ϸf�u��.�u��X�c?Z͖^�ʱ1�O[�nd.����N悌!�>�����k�aC�&p0�k���H��r�z��I�3��V^���J��@�ݡ�Ưh��a����u��.�t���LGQ�r���0�b�;<ă"ĥ��������2N�9y����4�����8�@�H�T����l�����[/��:����Q$UW^1�_���s����2C89�[�`^\-@�UtO_0ټ<������r��W�֢h����C^���ҦU����]�< ��_��ր����S��oB�?��p�~,>� 9�Dq��?�XEgRk��-��A���
�x��<��rj��P�k�~o��S�����Qt}�㎓KHP@\:&6'���{Pe�
l���ktM�����f�e r)*���5�a�}��%�(�o��Hޓ5�w��N;����gd���^J�a�A@��h{:M75��9�2�s�@��?�n�,@ �T�e�m
\ji�G`�)#;^�f��,`9�!���������[�#�c�s�Ɓ3�B<k�4�ն<w��_�Ө����L#�>(8�����$Q���9 (zΫ%reA����Ml'��JV�hb�q&E��
�Dj<>
(
0P�"���s	*ey�PO�"�qa��,��������0d5���ٖ̿����:s���bN�kݠ_��E?���ߧ�
 ���ޚ0�AD��3A"��Ǒ�,�p��)��$l5����Q5�{˰�e�ʫW?������uƄ�<pn��}�"�	�8H�x+�:���\��1��F{���f����Z���#>A�Uu\����,wGS�"��a3
���`�#�4�j�n���{�%�� �딜X���L�0z�������g�S'0���)ʼ(%��L�Ӣ����_< �$�!��k���Ϟ�ӻr�V�eW2�E��t��&��T[�T?׹P)9��",v*�����vS������3�"������c.S��k�������x��鷞gq>va#\��D[?k'��A�5��v{�&ʰ�E� m������Z�R��;'OՑf�iI�#qvO��&�	EJ;�[6ū-�Q1>��E��f�\ ��H�kY��̻���LI��!�J7�9Ik��N[A�5n�� �B*'�`� ��'B�Y��A"yR\-F�P��Ţ��%`���'��Yȭ��ր�����G!
g��?�l6��YO�6(�@ �Ƒ*�����HkR��>��n�Gqd��?4�WXY��ԥ�Y���/�lΕI���K�8U�`�={��ߊ92���	ثK�x�Ʈ���1�B���J� y��h�9"Q�j0�(0J���G��+̛�M���ѭ�bt��jkȼ��[��nN
=�'L*�.����ݣ���So���PgB�
����w��]T�_��G+a)_\	P }:u9O��$%ݞ�9>=~q~�.ޜ�=?K2n���e_�v�|��(I4�Ə�i�  �Έx@N�`t$胀ԢC�p��"U����Tb�d�Y�r`��8�)��	��	��B�{yp%ALr5�`�$/�C���c�� �'�S�xr�_�'e�u�q���������ua6v��>�:9��	[x�6�I�N�ȟ�R-;9~��7�\��h%&�������:������ȷ���$��@�Ѫ@����)4���<��A��* �i������aOa�/���G+�-��=lv[�����a����O��_b��T�K�%�y���������,]U����M.+f�[+�ZwuKJ���lk�iV�mNu�qZ!!�)�nA`#Iv2�5��R<�ia�X[Q[Ǟ�ۗ`Hn�L��ɘ`_���n�~��:�k��FϧN	�Κ|/O�GF�<!;�� ��\G�����H	���P	f��z�X�4�\�L���0*7Ҏ�$wZs5� �?�	�&�W!�]��eJ>����Ȋٕ��Wk��Y8#߈c����@$i��C����!�2�F�sC���۴%�2��	Nߗ1����>�n a�<���X}9�o�r �m�� �p7��%1uw�-��Z�B2�y��(jW���_�e+.(�:�i\1�g��k��&X���ן�ƁOr��w��������^N�zML��dB�2L�C>�/�_������$)�`S��݀[��,�1[T����	�!�㐂\4�IGp�	��:��ܕѲ�c��v�RC<�D����yt5i4���'�_0�2�n1�J$0k�l͵e"s��;��L��~+�i��@��"�9�LI��Ej(�Gĉ����z��/D�R�I��	�s��5s��yr���I_�r �8hN����5�pޤ��tb�S�sP��4��ZYۈ��L�@�%�@�`�Sb��y$��N��qK6/����I_²����/|�[X�kW�E,C�����'t�Vn��ʍ�0^}�F}�F}�F}�Ɠ�rC7�7�Yoܨ��x��5$��e�}�]Zg�6�Wi|��4�F���	W-�~��q˵�'����L�?x��[9������b����O�N<�%u�����[9о���h��𺘺.����?_15ꬃ���7WI]\�*\�jE��liͪ�*�KV��/�dUİ֪XM�M���e�jA�[Ww�]��BW�/����԰
]��KX� ���I �.`��Hqv%;�ސqo�hˬ�I3T-O��EC��PHܸ&=%�У�m��	�� ��7s$�n���U�;~c�g�Iۊ�)�'�d
��"�R���f��~�P(��m���35�ë�u��h�]a�(A鶭a���i�S�
����S���?*L�@#I䄘��U4W�\Es����\Z�0�� &9R@ګt�R��2�*�\���8PY��׽�HO��j2B]�^�]�$��4��
��R<X5�2kv�U�_ţ���-�?-�@���B#<�:|�C����>�x�H�BbIŦ(�I��:L]Д�bN���E��JK1ĺ$[Fq�_�1��)�\�܅���Q���� ��D���>h����v�����7;����O�T����B�,=Az�V���#�g�M�+Ь���ZR��^�eן����ޥp�!�\�h�8�� !�����R�".|]����m��2�X19)�~V���@�K�or��~tj'Y)I8��ҙ%V��Ff�(P�'�*��pb���:�S̀�3XrWN�N�\!�_��S��H�
ኘ@rӭJm�_��i3��20L�a<�
_А�&�w���_E�n��̟x��?(���_b,�-g���:0���ya2���8&E�Ia����\�Q���L�ʥ(���+��4ݗ�{��<���|0c7
W� 5R��4,�U"
&x�sw)��Z����*Uan�!ɖ�*�F��&f���J9��7ӄfo��O���U*�M;)���R'ߪ�.�d�#�R}��7;��#R��]/����C:�mK�;i�Җ�:�1�B�c�]?�!l\L�,,�ć�N!\7��L���xt-�	�g1�+��g�5�!"�Z��ٽ5���\��7��x�QC趏�M�x�������w��d��Uar`��9׽`K1�s���rl ~��,��4��O�:"n�U�I��S�Lܫǿm��޵�q�~[O)9Lx�Am�]p�*YR�o�<��O�$skM[I��-5��E������}"���݀߀x�~���TI��"���x"�g��Nv����V�4�
	��v14
�6Rv�8G��mȎ���$E���aY%����dWC���Y�Q��N��įi=�"�����f��f����&V�a�
�`��J�OJ�^4�Sa�(���BaJt��NJ%o����2dV�O@�O�D<!�e$�(�l�:��Y����[E��/�׌�-$4������M�~O����Mg���7f<�K,ybIIV2�_���Mk(����^oa^�G}"OOH1"��$v�Օ���n��-ĎB
�DE@�7��G2��9�.��(��ªX�.0Z������K��� �����4��+#�|q��=�~�
��uO�n7��Q $��R9%mTL*/w����I4�c�iP������1�M�=A���UV�tl����Q��ȉ�떩�t�
Z\�I?ܳX8��6� 9؆~�8�'@��fywx��챤��&��	���E[PK�8v����fb0��X�CM�96�S�a�T�zpJe���-,��#J��dB��u��I�G�ZP�~�N�@�}_v�Eӣ��g���_w���΍� "�7P�Щ3�5����S�X6��9^N\'�o�]b�e���Yuy1YZ��|���x�~}p�Oy�%Ւ�E������N^������ey��D�;������V�`6����\�3I|{uv�{z�r��ś׃�7�2�z�5��2�C9{$n���
nb��1�m�*ʐ�d>L|�"��}�:�/l�}���}����c?�����c�c_�a�ƞ�����/�b��`ڶ#|w�@ˈn�\>ÃdA�E�˞o7�V�!�d�0Y�A�<����n\A[��jL�������d�p��%;mk�p���r�ߜ��e.E��3�e�����Խ�\^��lh��a⣉D%-�5����ɟ);�N*�������b!��XR� �7�T���I��\�:��~�~�~�~�~�~�~�~�~�~�~�~�~�~��c=��|�� �  