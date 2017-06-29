#/bin/bash
#该脚本用于统计硬盘空间和表空间的使用情况，并邮件发出
#初始化环境变量
source /home/oracle/.bash_profile
cur_dir=$(cd "$(dirname "$0")";pwd) #脚本所在目录
home_dir=$(dirname $cur_dir) #上个目录
#获得本机ip
ip=`/sbin/ifconfig eth0 | grep Bcast | cut -d : -f 2 | cut -d " " -f 1`
#删除之前该脚本产生的日志文件
cd ${cur_dir}
echo ${ip}
if [ ! -e ${ip}.txt ]
 then rm  ${ip}.txt
fi 
#统计硬盘空间
echo -e "您好！
    $ip统计信息如下：\n\n" >> $ip.txt
echo "硬盘空间统计：" >> $ip.txt
/bin/df -Th >> $ip.txt

#统计表空间
echo -e "\n\n\n表空间统计：" >> $ip.txt
sqlplus -s scott/tiger << EOF >> $ip.txt
set feed off
set lines 400
set pages 900
col 表空间名 for a20
select x.tablespace_name 表空间名,已用,已分配,已用占已分配的比例,空闲的已分配空间,最大可用空间,已分配占最大可用比例,可自动扩展的空间
  from (select TABLESPACE_NAME,round(sum(BYTES) / 1024 / 1024 / 1024, 9) 已分配,
               round(sum(MAXBYTES - BYTES) / 1024 / 1024 / 1024,2) 可自动扩展的空间,
               round(sum(MAXBYTES) / 1024 / 1024 / 1024) 最大可用空间,
               to_char(round(sum(BYTES) / sum(MAXBYTES) * 100, 2), '990.99') || '%' 已分配占最大可用比例
          from dba_data_files
         group by TABLESPACE_NAME) x,
       (select a.tablespace_name,
               round(a.bytes / 1024 / 1024 / 1024, 9) 已用,
               round(b.bytes / 1024 / 1024 / 1024, 9) 空闲的已分配空间,
               to_char(round(a.bytes / (a.bytes + b.bytes) * 100, 2),
                       '990.99') || '%' 已用占已分配的比例
          from sys.sm\$ts_used a, sys.sm\$ts_free b
         where a.tablespace_name = b.tablespace_name) y
 where x.tablespace_name = y.tablespace_name
 order by 1;
exit
EOF
#把统计结果邮件发出
mutt -s "$ip统计信息" -- zhangwz@xx.net < $ip.txt

#每周五的15:30执行此脚本
#[oracle@ ~]$ crontab -l
#30 15 * * 5  /home/oracle/shell/check_tablespace.sh
