#!/bin/bash
#scripts for zabbix install
ZabbixAgentConfigureParameter='--prefix=/usr/local/zabbix --enable-agent --with-libcurl   --with-openssl '
ZabbixServerConfigureParameter='--prefix=/usr/local/zabbix --enable-server --with-net-snmp --with-libcurl  --with-mysql=/usr/bin/mysql_config  --with-openssl'
ZabbixProxyConfigureParameter='--prefix=/usr/local/zabbix --enable-proxy --with-net-snmp --with-libcurl  --with-mysql=/usr/bin/mysql_config  --with-openssl'
ZabbixServerAgentConfigureParameter='--prefix=/usr/local/zabbix --enable-server --enable-agent --with-net-snmp --with-libcurl  --with-mysql=/usr/bin/mysql_config  --with-openssl'
ZabbixProxyAgentConfigureParameter='--prefix=/usr/local/zabbix --enable-agent --enable-proxy --with-net-snmp --with-libcurl  --with-mysql=/usr/bin/mysql_config  --with-openssl'
#ZabbixConfigureParameter

#è„šæœ¬æ‰€åœ¨ç›®å½•
cd "$(dirname $0)"
ScriptsDir=$(pwd)
#ScriptsName
ScriptsName=$(basename $0)

#é€»è¾‘åˆ¤æ–­
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

#é€»è¾‘åˆ¤æ–­
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
#å¤„ç†æ–‡ä»¶
if [ ! -f ${ZabbixSourceCodeFile} ];then
        echo "ERROR: ${ZabbixSourceCodeFile} not exit !"
        exit 1
fi

ZabbixSourceCodeDir="$(dirname ${ZabbixSourceCodeFile})"
#åˆ‡æ¢åˆ°æºç åŽ‹ç¼©æ–‡ä»¶ç›®å½•
cd ${ZabbixSourceCodeDir} || {
        echo "ERROR: cd ${ZabbixSourceCodeDir}  fail"
        exit 1
}

ZabbixSourceCodeName="$(basename ${ZabbixSourceCodeFile})"
ZabbixSourceDirName=$(tar -tvf ${ZabbixSourceCodeName} | head -1 | sed -n 's@\(.*\)\(zabbix.*\)@\2@p')
#è¿›è¡Œè§£åŽ‹
tar -zxf ${ZabbixSourceCodeName} || {
        echo "ERROR: tar -zxf ${ZabbixSourceCodeName} fail"
        exit 1
}
#åˆ‡æ¢åˆ°æºç ç›®å½•
cd ${ZabbixSourceDirName} || {
        echo "ERROR: cd ${ZabbixSourceDirName}  fail"
        exit 1
}

#è¿›è¡Œå®‰è£…
install_zabbix
#è§£åŽ‹é…ç½®æ¨¡æ¿
unzip_zabbix_config
#æ›´æ–°é…ç½®
cd ${ScriptsDir}
update_zabbix_configure
#æ˜¾ç¤º
display_zabbix_configure
}


function install_zabbix() {
	#å®‰è£…ä¾èµ–
	echo -e "\033[33;1m Start install dependent application \033[0m"
	yum install gcc gcc-c++ openssl openssl-devel curl-devel tls-devel gnutls-devel fnutls-devel
	#é…ç½®
	echo -e "\033[33;1m Start Configure \033[0m"
	sleep 3
	./configure ${ZabbixConfigureParameter} || {
		echo "ERROR: ./configure ${ZabbixConfigureParameter} fail"
		exit 1
	}
	#è¿›è¡Œç¼–è¯‘
	echo -e "\033[33;1m Start Make \033[0m"
        sleep 3
	make || {
		echo "ERROR: make fail"
		exit 1
	}
	#è¿›è¡Œå®‰è£…
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

		#å¼€å§‹æ›´æ–°é…ç½®
		sed -i 's@\(^DBHost=\)\(.*\)@\1'"${ServerDBHost}"'@' ./zabbix_config/zabbix_server.conf
		sed -i 's@\(^DBName=\)\(.*\)@\1'"${ServerDBName}"'@' ./zabbix_config/zabbix_server.conf
		sed -i 's@\(^DBUser=\)\(.*\)@\1'"${ServerDBUser}"'@' ./zabbix_config/zabbix_server.conf
		sed -i 's@\(^DBPassword=\)\(.*\)@\1'"${ServerDBPassword}"'@' ./zabbix_config/zabbix_server.conf
		sed -i 's@\(^DBPort=\)\(.*\)@\1'"${ServerDBPort}"'@' ./zabbix_config/zabbix_server.conf

		#ç”Ÿæˆè¿žæŽ¥å¯†é’¥
		openssl rand -hex 32 > ${ZabbixInstallDir}/etc/psk/zabbix_server.psk

		#å®‰è£…zabbixç›¸å…³ç®¡ç†è„šæœ¬
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

                #å¼€å§‹æ›´æ–°é…ç½®
                sed -i 's@\(^DBHost=\)\(.*\)@\1'"${ProxyDBHost}"'@' ./zabbix_config/zabbix_proxy.conf
                sed -i 's@\(^DBName=\)\(.*\)@\1'"${ProxyDBName}"'@' ./zabbix_config/zabbix_proxy.conf
                sed -i 's@\(^DBUser=\)\(.*\)@\1'"${ProxyDBUser}"'@' ./zabbix_config/zabbix_proxy.conf
                sed -i 's@\(^DBPassword=\)\(.*\)@\1'"${ProxyDBPassword}"'@' ./zabbix_config/zabbix_proxy.conf
                sed -i 's@\(^DBPort=\)\(.*\)@\1'"${ProxyDBPort}"'@' ./zabbix_config/zabbix_proxy.conf

		sed -i 's@\(^Server=\)\(.*\)@\1'"${ProxyServer}"'@' ./zabbix_config/zabbix_proxy.conf
		sed -i 's@\(^Hostname=\)\(.*\)@\1'"${ProxyHostname}"'@' ./zabbix_config/zabbix_proxy.conf
		sed -i 's@\(^TLSPSKIdentity=\)\(.*\)@\1'"${ProxyTLSPSKIdentity}"'@' ./zabbix_config/zabbix_proxy.conf

		#ç”Ÿæˆè¿žæŽ¥å¯†é’¥
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

		#å¼€å§‹æ›´æ–°é…ç½®
                sed -i 's@\(^Server=\)\(.*\)@\1'"${AgentServer}"'@' ./zabbix_config/zabbix_agentd.conf
                sed -i 's@\(^Hostname=\)\(.*\)@\1'"${AgentHostname}"'@' ./zabbix_config/zabbix_agentd.conf
                sed -i 's@\(^TLSPSKIdentity=\)\(.*\)@\1'"${AgentTLSPSKIdentity}"'@' ./zabbix_config/zabbix_agentd.conf

		#ç”Ÿæˆè¿žæŽ¥å¯†é’¥
                openssl rand -hex 32 > ${ZabbixInstallDir}/etc/psk/zabbix_agentd.psk

		AgentConfiureUpdate='True'
		InstallStatus=$((InstallStatus+1))
	fi


	#æ·»åŠ ç”¨æˆ·
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

	#åˆ›å»ºç›¸å…³ç›®å½•å¹¶ä¸”æŽˆæƒ
	mkdir -p /var/run/zabbix && chown zabbix.zabbix /var/run/zabbix -R
	mkdir -p /var/log/zabbix && chown zabbix.zabbix /var/log/zabbix -R

	return ${InstallStatus}

	#æŠŠç›¸å…³é…ç½®å¤åˆ¶åˆ°ç›®æ ‡ç›®å½•
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
        #æ‰“å°å‡ºæ¥
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

	#æ¸…ç†é…ç½®
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
	echo "$0 /tmp/zabbix-XXX.tar.gz	è·Ÿç‰¹å®šzabbixæºç è·¯å¾„è¡¨ç¤ºå®‰è£…"
	echo "$0 add_zabbix_config	è¡¨ç¤ºè¿›è¡Œæ·»åŠ zabbixé…ç½®æ¨¡æ¿åˆ°è„šæœ¬"
}

Main



exit 0
#This line must be the last line of the file
__ARCHIVE_BELOW__
‹ v¦0_ í=û[ÛH’ó+ü=Ã~G˜3à6Yn<wÈÄ7xÌÞnvnO¶ÚXYòèxööþö«ªî–º%Ù’	IÈ¬4ó}1V?ªª«ëÕUí_­ÑÈ¹ÿëØ÷&ÎÍþWåiÂsØíÒ¿ðdÿ¥Ï­Îaë Õî4»¯šðo÷ð+Öý8à˜OFVÀØWïG«Ú•½ÿBŸ_õ—…<¸åÁ~ùsà÷–¬ç ÛjÓú·{½vçÚµz­ÖÁW¬ù“—=ÿäë¿Å®§NÈà‹	&ˆ+r|M—³‰°?S0ÁÌ¶øÌ÷6¡ŸÏnxÄf~À™ãAÃ™ègü8’ìÖ	ˆM£h~´¿ww·'Xxk¶¹¹¥=ì‡³×g—Ççlx|y|qv}vyÅ¶²uaoæ8Ñ;wÂˆ{C?ˆ6·6ÄlÔQ`ÍçÀÄ›[ ë…åÙVä‹#æùð÷¥åÝð#Öj¶v;íÃÞ!|wÊ'VìFG›é°ýV³Ùm™“^ùq0æƒ!L)>²ÁY¶ð0¤‰ûßñnœc¯°ŠdÆ­dÔ~Cÿæz1ç8×œ‰ÃCv7å@q×¿a3˜Òº¯,øâ.p"$@äÃxá˜1¶Ëà4ÆïhE~GŸB9¤ÍîœhŠs½Ä¯çV`ÍxÄì8„>|	ÃD}`#~ó8*CHBÞÇ™r8á<¸d€AâÁ„D;Ù‹mã×Û)(¥ô“ƒùÔ§ý[+ØÄ¥LËˆ6¤HTWÎ¯Ù…uïÌâáOæOˆÚ©ã±‹ ÍFHb;¡5‚/­8ò‘ùÇÔ.ð#Ú+9¯¹‹¼gp]
@?Ãr§|ßœó[îŒ`ã×ÌÅï$D#+(ò»e\„<	ÐÀþ|Ž broÏÌÄC§ãŒ™œ±åêCÁ«6¼âA e~ßïï¬ÀƒAq„ä0hD ÞàLÏ`;†)€BQˆkì@—.Ž|ük;õ,½œ¬ÙYMâ®É#)û“ÀCÇ–,ù9ÀNiÁKOvÌÄ^1³Í;³ /^ù!
­S+²`Í8›Âß´·¶ìd ,¾k°Ð¿‡/APÇ!Ðé{±¸úÃ¹ÙÏæÑV8 êöÂ`7W¡&`ì'd1@Jé(à_Â$0ºñì_+ •­ÑšÊe#ŽLwëÀzïÁhoTÄœ§/†VÞù hPª97¬¹ƒu¬j,.û_~+új<å3w}@³·Š8ƒÐ¨M€T&ÔV2n?;b¥ÓV!ØcÍ((UaŠ°“Ì‰ÍôÉæò»%nœø³÷€kPÿ»ŽÄžÀÄI?Å6¥|¢&ÏAuEìS%ÃJ®¬BUjØßfóýÙ"üÅÝÃ®9Ü…þOñF ”¤#F€Êâb5qåÐ­„^·ÛÑä	{–lÀ¢ZN³—1jŽO:~}rvºÊªÉØ(ª‡¾ëò eéëx6‚­"ið]˜ô= îx¨Q,â÷¢m©ºi6uúêÓ€™S Ã`x1Xlÿ@`¶r3ö‹ ’ïÞz·ÆST½ëˆ–;Nû’ÌÙ3Ç»±\BàÞÿOëÖÚÁ=r~µ@\ù—ã,F	5P¨q/ü&v­ !Æ…^8¬‚GùFŠyÙ«´x5úí"ª]C¸Ú"J«pCudÖxÌç F<0Ú3†-›þ,õ@}¾¼»³èÄKH•ß€Ä¿Ë%GY9«2CrÄDâ„s×Z(/(é¸ÖÈqPw8Ã­ÃïØ/1‘'ÀJ‹¦aóÐ¤x7*ôûÝ"V°*oŒ“‹!›‹EÎ–µéÝ©Ž} IUhì´}	0ínžé´Ù
¡yu}=\Gh`û‘`Ú|ÅRìÚ™Uæ}jJœOŸvÄ»¨[làTçæ…@ìÉ€Ì7³d4‰Ë8¾MÃ¼ñÜ…`D' †¦ñ“A§ÐÑ…‰ñ}qÿi)Ïà…+s‚
Ä±ªƒ'ÍË—¥ t¶,0(°"~g-ÐrM}çg !Q–¢M¶£ù&$5oD„ªÿ%vP‡ƒœÕÅ*+ª¤(ý¥@Jóÿµ²¢"°À|Ânµ×WoØÊNGa‡vÁb»uv—N™‡ImÆB•üÓø}ü[ŒWñÖíÛæS8×B[ÅÓfaï_"—poŒŒöÊ¿0@"×ïÎq]¥ÉPÁˆ.¤_Ø†ð?Š`_2ð@µ S²¶»Ï{Y"f é÷
ò`ò8À‚ô ï%Él€´ì°;TÄäJFJ$dc|ÕÀpÉh	5µpÃÎ8xñYAS*¸PÇËŽh±ËÉkuÒA“õ.ßæÅv·÷ãnû‡"èûÏ/Š°CYêc K¹Laa€¸h†ÀjØaž¯ï,'¦&µ9(.L$sÅJ¤{§xM$DyE÷úb(­Æ¸æ3pƒ, 3yÜ‰÷¾©,àÂ¾dÉÀ.òª$ºÀX˜4Æè[X!®«q`×¿|ÌŠt¸hç<×áäò0¨‰‰pý´™Â=ø¢@iýD8¤ÕH1Ó-Kði+šÜRG›%+pDÌ˜¢ÂøwË3‹ÙÜufàaÚZ˜˜´¾E€áÔ][*¡G”.vò†Yð—Ç#p¹ß3´‚‰…òö	¹òIÐ‘9´àåñS	¿¹GÿmêßµÚ‡ômF“¿ò¯ÞsŽ¦m¹ô’’	¶PÚK,‹ÃÆ 7_!ù]úÐˆF ¬yK!Ë8HÏ¥1Nbd$¦Š3ñ|Ô?·áHFCÃÛŽ8ëú–ÍíÆ=(¸ëâ±2ÕÂ¥œ¸Ä…Ðã.ß“cà<^Œ]¸ÑqcÀ3	°ëßˆ®³tuˆ_ã¹9®3ØJ `äÎî4a­½8ÂÓ€	.¾Þ‡ÿ#Æø1ê7‰xSJc ly…0¿çã‘¡l
~Rwxø°çç2à½1ðŽ1ƒM…9»”X¥„BLÕzÀx0…€‹)\t#‹H<Š#Š¹dÄ‹•k‡F;¾¹ß‰%_ÚÖ¢Ô907N1E3;åÂº×xð”pÆÇýO1„o4âCde²o"+|~C¼dß(W—(ŠÇ ï´¡ûç{GS U€séÛ[ËùÏ¸f¯uÞß.‚u›þXèc?ZÍ–^ùÊ±1®O[”nd.òø±å‹Næ‚Œ!Û>¬¼ˆäñŒ€kÈaC‰&p0žkáñ‡ÅH›¡râzŠ—I”3·ÇV^ø±ˆJ¼÷@ºÝ¡ôÆ¯h¯ãaß×åÖuÎÀ.¢t¿‹ÍLGQ•r¶´0Ãb°;<Äƒ"Ä¥–•ìÝÝíô2N¶9y¿“®È4õþú– 8ï@±HûT¹Üåælûù»Ï[/µñ:í‹ÈßÎQ$UW^1µ_…¤¤s™×Ë2C89³[„`^\-@ôUtO_0Ù¼<¢ö¨©r‘ÅW®Ö¢hù§âÕC^ö¬¶Ò¦UŸ¨ßê]‚< †¾_·ƒÖ€žÚëàS×ÂoB×?ÈàpÀ~,>Â 9õDq–¨?¡XEgRk€Œ-ÉôAÁ ³
ƒx‰Î<Š¤rjªúPŸkµ~o¢½S•œ»¸ÌQt}€ãŽ“KHP@\:&6'ÏÀ{Pež
lÊÇï«ktM¢üÃÎæfò±™e r)*ù¶Ê5™aØ}Žü%½(¤oµ˜HÞ“5èw²ÚN;Î’¡‡gdÐæà^JÎaÄA@„æh{:M75öä9Á2×s…@ÎÒ?ènæ¿,@ ™Tºeêm
\ji¹G`Ó)#;^¼fïè˜,`9í¢!÷¡«ò›€õ[™#™c´s®Æ3B<kÆ4„Õ¶<wÆã_ÒÓ¨¸ÁŠL#Š>(8ÔÁ®Íç$Q«û³9 (zÎ«%reAéÿîï¸Ml'ø‡JV™hbâq&Eì¿
Dj<>
(
0P“"ñíøs	*ey¥POæ"±qa½ç,Œ…×‰ïÙÈñ0d5…‹Ù–Ì¿óÀö˜:s²¯ÞbNŽkÝ _Š„E?ƒýÆß§™
 î­‚¸·äÞš0‹AD’Ž3A"¸Ç‘Ø,äpÌÉ)Œü$l5ÞöÒèQ5ä{Ë°ïeŒÊ«W?òÅôçñÈuÆ„Ë<pnÑø}Ï"À	…8HÏx+¥:óå¯\ÿî1ÈÊF{¥©•f¶’£ZŠœ#>A÷Uu\œ›´è,wGS¥"¦Œa3
–¥é`Ê#ì4Øjän’àç{Û%õ… Íë”œXé•óõL¼0z˜ù¦“óû®góS'0‚¹°)Ê¼(%²èLñÓ¢ÓëÀ¿_< Ç$!‡ùkœßä¦Ïž®Ó»r®VºeW2¼E‚ÎtÆÈ&„å´T[ÓT?×¹P)9ÿñ",v*¾¢žùvSâÛöÁ·™3¾"Äú¤éòøc.Sì•ákšÃâüŒÈëxçÑé·žgq>va#\‚ôD[?k'¸Aì¡5·v{&Ê°·E€ mœ†÷ÁZ‘R±’;'OÕ‘fçiIÑ#qvO™‰&ƒ	EJ;„[6Å«-ŒQ1>™àEŒáf©\ ‘˜HŠkYˆ±Ì»•ŸËLI®ì!„J7ü9IkÇå˜N[Aâ5n€å ÌB*'¤`œ ¥‹'BÕYŠŒA"yR\-F‰P¢ÄÅ¢´Ì%`¡‹ø'Œ²YÈ­ôºÖ€…ƒ™ƒÇG!
gõ‰?èl6‰ŠYO6(Í@ ÚÆ‘*Å“ùŒÁHkRâà>€n±GqdØ‚?4ƒWXYœÂÔ¥¢Y¢‹Š/ùlÎ•I¯‘–Kå8Uû`Û={ÍæßŠ92æÁù	Ø«KìxËÆ®ƒÁÆ1´B³¤¿JÈ yïøhé9"QÁj0À(0JÃÐÝGÂü+Ì›¼MóéðÑ­ bt¬üjkÈ¼Õ[„ènN
=Ö'L*°.ŸïÈÝ£°•’So‹êPgB‚
¬¤†»wŽ±]T˜_æ¯G+a)_\	P }:u9O›†$%Ýž¿9>=~q~Æ.Þœ¾=?K2n³¦¦e_øv®|‰Ë(I4£Æéi™  ¸Îˆx@Nµ`t$èƒ€Ô¢Có¸p‰"U‚¨åTb‘d¯Yär`øÐ8ñ)“´	ûß	ˆöBÿ{yp%ALr5‰`â$/åC›šØc‘þ ¥'àS‚xræ€_Ú'e§uèªqÅõùÕîåÙùñua6vÆö>¿:9–¹	[x²6ÄIò”Né€ÈŸïR-;9~îâ7\®Þh%&½‚©Ÿ‡õò¼:°¿õÑÀÏÈ·òÉÅ$³Ã@ëÑª@æøæŸã)4¯•œ<ˆ×A¥é„* Èiú›Ÿ»’óaOaý/Úÿ‹G+ÿ-«ÿ=lv[™úßîáa³®ÿýOõú_bŠ§TþK¾%ˆyÜâÂËõç‡ý,]Uò³æÊÆM.+f¢[+ûZwuKJÿÔì¹lkåiVÈmNuîqZ!!Í)¤nA`#Iv2ô5¬ÞR<²iaÊX[Q[ÇžÛ—`HnµLšØÉ˜`_ù¡Õnîµ~¸×:Ük·ŸFÏ§N	¡Îš|/OšGF¯<!;´¨ ü•\G€ì­çüó†H	¹¼ŽP	fµ…zÔXƒ4Å\’LÂå×0*7ÒŽË$wZs5ï Ï?	…&ŽW!Ï]õ„eJ>žøïãÈŠÙ•þíWk÷ÔY8#ßˆc³“å@$i¥ÂC¥§Ú!„2©FƒsC•ÞÁÛ´%–2¯‡	Nß—1µ¯ê»ê»>ìn aö<½«¶X}9Àoïr ÁmõÝ p7ÀÆ%1uw€-Ž‡ZéB2™y§¡(jWñš±–_Ôe+.(¾:ái\1ðg«×kÝƒ&X¦ÎÅ×ŸìÆOrßÀw°áå›ÿú»ž^N–zMLÝñdBì2LÌC>/Ï_‹”ù†²Î$)´`S‹¼Ý€[öö,¼1[Tš¦‹’	ã!ã‚\4¨IGpð	ôÄ:ïùÜ•Ñ²²cçÃvþRC<«Déý›Éyt5i4’ Æ'Ë_0µ2én1¦J$0kélÍµe"s‚§;¿äLµÖ~+ãi½â@¯·"ý9ùLI˜ªEj(šGÄ‰˜Òãôz¾—/D½RÅIî‚	´sÂéÓ5s‡Ðyr ŸšI_‘r À8hNØ…éú5òpÞ¤çÇtb‹SÊsP„å«4¶§ZYÛˆ¦—L¬@à%’@`âSbšÚy$äîN…å—qK6/«¾„åI_Â²µŒ…×/|ê[XôkWÄE,C¯¾¥ð‚'tÊVnÆúÊ²0^}åF}åF}åF}åÆ“ºrC7ë7þYoÜ¨ïÖx”»5$„æeÂ}à]ZgŠ6×Wi|¶«4éÂFîÆ	W-‡~žÑqËµÛ'¬ÛßÊLÖ?xâ…û[9¾´Òý­bøòÅûO¸N<Ã%u™ø•‰á[9Ð¾œ’ð­h¹¢ðº˜º.¦®‹©?_15ê¬ƒ´Öñ7WI]\µ*\…jE«òŒliÍªÈ*©KVë’Õ/¦dUÄ°ÖªXM‹Mª¬­e½jA¥[Ww¬]¿˜BW™/¨¶õÉÔ°
]óÄKX Ýú¬I ½.`ÅÊHqv%Í¾ÔÞqoíhË¬¸I3T-Oÿá–ECåèPHÜ¸&=%ÆÐ£ºmŸ	©ô ö¸7s$ônƒº§U¾;~c¾gêIÛŠÐ)à'ìd
 …"¼R„êðf¯Ò~šP(Èúm 35ªÃ«µu”ñhª]aÏ(Aé¶­a¹­åiµSé
õÑÜêS¶›Ñ?*Lú@#Iä„˜éÙU4WÊ\Es…Åá“ä\ZÅ0·Œ &9R@Ú«tæR°´2Þ*«\ÐœŽ8PY¥Õ×½úHO€Äj2B]‡^µ]¤$¢ñ4Ãý
ÁÇR<X5¬2kvðUÓ_Å£¿‘ä-?-×@ÿ…øB#<±:|ÔCËð³ÓÃ>Øx©H„BbIÅ¦(ŠIŒ‡:L]Ð”ÀbN¸¤ÊEÇòJK1Äº$[FqÚ_è1Ê)\úÜ…êõóQžÂûè ÊþD¿ÿÞ>hõÄý­v§Ùíàï¿7;úþ‡OñT¿ÿ˜B¥,=AzVÌ¸â#ÕgÊM+Ð¬ë®»îZRúé^×e×Ÿ¯ìú“Þ¥pæ!Ó\‚h‹8­Â !ùÞ¬«€Rä".|]Œ•åýmÚî2¤X19)á¶~V‚•œ@“KôoràŠ~tj'Y)I8§œÒ™%V˜ðFfã(P¹'ÿ*Ýã…pb…ªŒ:ÈSÍ€»3XrWN¥N½\!Ì_£ŠS“‚H‰
áŠ˜@rÓ­Jmé_”îi3”ä20LÅa<§
_Ð’&âwƒ¶“_EÛn°í££ÌŸx´ïˆ?(ïúó_b,¯-gÖìå:0’øÿya2¬¬›8&EIa‰ªê”\íQ­»âL¶Ê¥(•¨+Ž¢4Ý—ô{ºš< Š¼|0c7
Wñ£ 5Rµœ4,¹U"
&xõsw)¡ZªŸ¡ú*Uanì!É–ê*¦Fúû&f»ä€ÙJ9’7Ó„foÁ®O†ÄåU*òM;)²±ÀR'ßª­.®d…#âR}¯Ó7;€¤#RƒÍ]/‚œ™õC:©mKç;iøÒ–êµ:×1ÓB’cî]?ç!l\LŽ,,ì§Ä‡ôN!\7••L·”ìxt-„	¾g1–+Ëçœg†5ˆ!"“ZéõÙ½5›»Ü\‘ô7Úx¯QCè¶¿MÝxòíç£½w­ödŒßUar`ˆâ9×½`K1¢s©ÊÒrl ~š—,“ñ4é…ÚO¹:"nÞUðIîßS¼LÜ«Ç¿m‹•Þµµqª~[O)9Lx¦AmÊ]p¬*YRÕoæÂ–<²ðO$skM[I€Š-5“íEý‚ö…þ«}"ìþÝ€ß€x‘~¬”¥TIìé"‘‚¿x"Ìg•ÈNv¹ºèâVñ4È
	Ôîv14
û6Rv‡8G–ÄmÈŽ©á‘å$EÈaY%ÍÉòdWCõ—ÓYòQ­N†ÕÄ¯i=æ"œÆòÒç‚fòè¥fÅø˜±&VåaÃ
Á`éJOJ¥^4¡Saù(¢’¤BaJt±‹NJ%o×Ùüú2dVé’O@ÒO…D<!¹e$Ù(¢l‡:òêY´½üÍ[Eóç/Ç×Œà-$4ý¶¬Ë…ÉM”~OÝÖÎìMgËË7f<ÀK,ybIIV2Õ_‚À®Mk(¨ˆŸÍ^oa^ãG}"OOH1"®À$vÝÕ•»½n·Ó-ÄŽB
ÙDE@é7âÑG2¢‰9õ.í×(ýÂªXƒ.0Z‚–£¿ûKäÈá§ óå²ÖÔõ4½’+#Ú|q½Í=•~˜
—í™uOn7ðØQ $æÄR9%mTL*/wÉÿŒªI4õc•iP±Êý™¨â1ê½Mú=A’‹¤UV„tl¤ÈÕÙQÂÈ‰Àë–©¶t…
Z\÷I?Ü³X8³è6Š 9Ø†~×8†'@ô“fywxèòì±¤¥Ö&½	•¾çE[PK8v‘‡’fb0øýX«CMð96ŒS²a¸TØzpJe˜­¹-,Éí#J“…dBå¾uì£ÛI¸GÁZPü~þNœ@á}_vã¿EÓ£½£gïš»¿ÿù_wðüÍÎ× "Á7PìÐ©3Æ5®˜ÒÁSìX6Æò9^N\'•oò]b–eóŽÕYuy1YZ‘¤|™–°xÚ~}p­Oyò²%Õ’—EÛåÉËô¾N^®“—¿œäeyëD»;¬–À¬–VÉ`6›¯“Â\Ø3I|{uv¹{zörðÝÅ›×ƒë7—2ßz¡5á¦ã—2C9{$nóÂÒ
nb¼à1”m»*ÊŽd>L|‘"³é€}„:â/l›}Ãþ‡}Ëþ½c?³¿³°ÿc¿c_³aÿÆž±öûžý/Ûbÿ`Ú¶#|wÑ@Ëˆn™\>ÃƒdAñE„Ëžo7éV½!õdÊ0YªAš<‰÷«Án\A[•ëjLÕÿâ÷ïŒ°ÿ÷dÎp¥‘%;mk»p’êôrßœðãe.EóÄ3—e¬ú¡™ËÔ½Î\^š¹lh™Ëaâ£‰D%-ë5ëÂÔÙÉŸ);¹N*®“Šë¤â¢¤b!¬ŸXR± ê7•T¼úéI¥«\º:¸~ê§~ê§~ê§~ê§~ê§~ê§~ê§~ê§~ê§~ê§~ê§~ê§~ê§~êçc=ÿà|ÁÕ È  