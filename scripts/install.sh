#!/bin/bash
# check root
if [ $UID -ne 0 ]; then
    printf "Failed! Please switch to root and install again. \n";
    exit 1
fi
# check systemd
if ! command -v systemctl > /dev/null; then 
    printf "Failed! systemd not found, please use CentOS/RHEL 7 or Debian 9 . \n";
    exit 1
fi

install_dir="/usr/local/janusec"
#pg_version=`psql -V | awk -F " " '{print $3}'`

printf "Installing Janusec Application Gateway... \n"
printf "Requirements:\n"
printf "* CentOS/RHEL 7 or Debian 9, x86_64, with systemd \n"
printf "* PostgreSQL 9.3/9.4/9.5/9.6/10 (Master Node Only) \n\n"

printf "Installation Path: ${install_dir}/ \n"
printf "Please select one of the following node types: \n"
printf "1. Master Node (default, there must be one master node) \n"
printf "2. Slave  Node (optional) \n"
printf "3. Exit (No Installation) \n"
printf "Your option(1/2/3):"
read option



case $option in
1) printf "Installing as Master Node \n"
if [ ! -d ${install_dir}/log ]; then
    mkdir -p ${install_dir}/log
fi
if [ ! -f ${install_dir}/config.json ]; then
    \cp ./config.json.master_bak ${install_dir}/config.json
fi
;;
2) printf "Installing as Slave Node \n"
if [ ! -d ${install_dir}/log ]; then
    mkdir -p ${install_dir}/log
fi
if [ ! -f ${install_dir}/config.json ]; then
    \cp ./config.json.slave_bak ${install_dir}/config.json
fi
;;
3) printf "Bye! \n"
exit 0
;;
esac

\cp -f ./janusec ${install_dir}/
rm -rf ${install_dir}/static
\cp -r ./static ${install_dir}/
\cp ./janusec.sh ${install_dir}/

# Check OS from /etc/os-release, ID="centos" or ID=debian or ID="rhel"
os=`cat /etc/os-release | grep "^ID\=" | awk -F "=" '{print $2}' | sed 's/\"//g'`
full_service_path=/lib/systemd/system/janusec.service
if [ $os == "centos" ] || [ $os == "rhel" ]; then
    full_service_path=/usr/lib/systemd/system/janusec.service
elif [ $os == "debian" ]; then
    full_service_path=/lib/systemd/system/janusec.service
fi


printf "Installation path: ${install_dir}/ \n"
printf "The config file is ${install_dir}/config.json \n"
printf "The following steps should be handled manually. \n"

if [ $option == 1 ]; then
    old_pg=`cat ./janusec.service |grep postgres | awk -F "=" '{print $2}'`
    new_pg=`systemctl list-unit-files | grep postgres | head -1 | awk -F " " '{print $1}'`
    if [ -z "$new_pg" ]; then
        # No PostgreSQL, delete After=postgresql.service
        sed -i '/postgres/d' ./janusec.service
    else
        # Exist PostgreSQL
        sed -i "s/$old_pg/$new_pg/" ./janusec.service
    fi    
    \cp -f ./janusec.service ${full_service_path}
    printf "* PostgreSQL 9.3/9.4/9.5/9.6/10 and prepare dbname,username,password \n"
    printf "* Fill in the config.json with dbname,username,password \n"
else
    \cp -f ./janusec.service ./janusec-slave.service
    sed -i '/postgres/d' ./janusec-slave.service
    \cp -f ./janusec-slave.service ${full_service_path}
    printf "* Fill in the config.json with:  \n"
    printf "* node_id   (generated by admin and master node) \n"
    printf "* node_key  (generated by admin and master node) \n"
    printf "* sync_addr (for sync with the master node) \n"
fi

systemctl enable janusec.service

printf "Done. \n"
