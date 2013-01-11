#
# さくらVPSにGyazzやQuickMLをインストールするスクリプト
# OSはCentOS
#
# サーバのセットアップを一瞬でできるようになっていれば
# サーバが腐っても困らないはずなので、こういうのを頑張って
# 用意しておくのも悪くないと思うのだがどうだろう?
# サーバ上のプログラムはyumなりgemなりGitHubなりで簡単に
# インストールできるようにしておき、データだけしっかり
# バックアップするようにしておけばよいわけである。
# ノートパソコンにもこの手のものを用意しておけば、新しい
# パソコンを買ってもすぐに環境設定ができて嬉しいかもしれない。
#
# 年間1000円でドメイン取って月額1000円で自由にサーバ運用
# できるというのは非常にお得な話だと思う。セットアップが
# 楽だったら誰もが使うのでは?
# 完全にすべてクラウド使えば自分でサーバ持つ必要はないが、
# 秘密のデータを使うときなど「エンタープライズ版」が欲しい
# ことも多いだろうし、自由にいろいろ実験したりする場合も
# あるだろうから自前サーバは魅力的だと思う。
#
# ■ masui.orgのセットアップの場合
#
# hondana.masui.org とか enkai@ml.masui.org とか使えるようになる
#
#   % ssh root@masui.org (さくらのルートパスワード入力)
#   # adduser masui
#   # passwd masui (パスワード入力)
#   # visudo (rootの行の後にmasui追加)
#   # exit
#   % ssh masui.org (masuiでログインしなおし)
#   % git clone https://github.com/masui/ServerSetup
#   % cd ServerSetup
#   % make hondana, etc.
#
# ■ DNS設定が別途必要
#    a @ 49.212.141.128
#    a * 49.212.141.128
#    mx @ 10
#    mx @ 10 ml
#
# ■ メールだけ普通にインストールする場合はpostfixとdovecotだけ
#    インストールすればいいが、QuickMLを入れても損は無いと思う
#
# ■ TODO
#  - 普通のWebページ (e.g. http://masui.org/)
#  - Gyazzのアップロード機能が動いてないかもしれない - 要確認
#  - Gyazo (gyazo.masui.org)
#  - Gyamp (memo.masui.org)
#  - Gyamm (archive.masui.org)
#
# 2013/01/11 14:17:47 masui@pitecan.com
#

DOMAIN=masui.org
IPADDRESS=49.212.141.128
EMAIL=masui@pitecan.com
HOME=/home/masui

all:
	@echo make quickml
	@echo make hondana
	@echo make gyazz

emacs:
	sudo yum -y install emacs

postfix:
	cat etc/postfix/main.cf | sed \
		-e 's/%DOMAIN%/${DOMAIN}/' \
		> /tmp/main.cf
	sudo mv /tmp/main.cf /etc/postfix/main.cf
	sudo chmod 644 /etc/postfix/main.cf
	sudo chown root /etc/postfix/main.cf
	sudo chgrp root /etc/postfix/main.cf
	sudo /etc/rc.d/init.d/saslauthd start
	sudo chkconfig saslauthd on
	sudo /etc/rc2.d/S80postfix restart

dovecot:
	sudo yum -y install dovecot
	sudo cp etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf
	sudo cp etc/dovecot/conf.d/10-mail.conf /etc/dovecot/conf.d/10-mail.conf
	sudo chkconfig dovecot on
	-mkdir ${HOME}/Maildir
	sudo /etc/rc2.d/S65dovecot restart

quickml: ruby
	-cd; git clone https://github.com/masui/QuickML.git
	-mkdir ${HOME}/QuickML/mldata
	cd; cd QuickML; ./configure
	cd; cd QuickML; make
	cd; cd QuickML; sudo make install
	cat etc/postfix/transport | sed \
		-e 's/%DOMAIN%/${DOMAIN}/g' \
		> /tmp/transport
	sudo mv /tmp/transport /etc/postfix/transport
	sudo chmod 644 /etc/postfix/transport
	sudo chown root /etc/postfix/transport
	sudo chgrp root /etc/postfix/transport
	sudo postmap /etc/postfix/transport
	cat usr/local/etc/quickmlrc | sed \
		-e 's/%DOMAIN%/${DOMAIN}/' \
		-e 's/%EMAIL%/${EMAIL}/' \
		-e 's/%IPADDRESS%/${IPADDRESS}/' \
		-e 's!%HOME%!${HOME}!' \
		> /tmp/quickmlrc
	sudo mv /tmp/quickmlrc /usr/local/etc/quickmlrc
	-sudo mkdir /usr/local/share
	-sudo mkdir /usr/local/share/quicml
	-sudo mkdir /var/log/quickml
	-sudo mkdir /usr/local/share/quickml
	sudo cp ${HOME}/QuickML/messages.ja /usr/local/share/quickml/messages.ja
	sudo cp etc/rc.d/rc.local /etc/rc.d/rc.local
	sudo /usr/local/sbin/quickml-ctl start
	echo '10 * * * * /usr/sbin/postfix stop; /usr/sbin/postfix start; /usr/local/sbin/quickml-ctl restart' > /tmp/crontab
	sudo crontab /tmp/crontab

gyazzdir:
	@if ! test -e ${HOME}/Gyazz; then cd; git clone https://github.com/masui/Gyazz.git; fi
	-mkdir ${HOME}/Gyazz/data
	-sudo mkdir /var/log/httpd/gyazz

gyazz: gyazzdir passenger
	-sudo gem install sinatra
	-sudo gem install json
	cat Gyazz/lib/config.rb | sed \
		-e 's!%HOME%!${HOME}!' \
		> ${HOME}/Gyazz/lib/config.rb
	echo '' > ${HOME}/Gyazz/public/index.html
	chmod 755 ${HOME}
	sudo apachectl restart

hondanadir:
	@if ! test -e ${HOME}/Hondana; then cd; git clone https://github.com/masui/Hondana.git; fi
	-sudo mkdir /var/log/httpd/hondana

hondana: hondanadir passenger mysql
	sudo gem install rails --version 2.3.11 
	-echo 'drop database hondana' | mysql -u root
	echo 'create database hondana' | mysql -u root
	mysql -u root hondana < Hondana/empty.txt
	chmod 755 ${HOME}
	sudo apachectl restart

apache: gyazzdir hondanadir
	sudo yum -y install httpd
	sudo chkconfig httpd on
	cat etc/httpd/conf/httpd.conf | sed \
		-e 's/%DOMAIN%/${DOMAIN}/' \
		-e 's/%EMAIL%/${EMAIL}/' \
		-e 's!%HOME%!${HOME}!' \
		> /tmp/httpd.conf
	sudo mv /tmp/httpd.conf /etc/httpd/conf/httpd.conf
	-sudo apachectl restart

mysql:
	sudo yum -y install mysql-server
	sudo yum -y install mysql-devel
	sudo chkconfig mysqld on 
	sudo /etc/rc2.d/S64mysqld restart
	sudo gem install mysql

passenger: apache gem
	sudo yum -y install curl-devel
	sudo yum -y install openssl-devel
	sudo yum -y install zlib-devel
	sudo yum -y install httpd-devel
	sudo yum -y install apr-devel
	sudo yum -y install apr-util-devel
	sudo gem install passenger
	yes '' | sudo passenger-install-apache2-module

gem: ruby
	cd /tmp; wget http://production.cf.rubygems.org/rubygems/rubygems-1.8.24.tgz
	cd /tmp; tar xvzf rubygems-1.8.24.tgz
	cd /tmp/rubygems-1.8.24; sudo ruby setup.rb
	sudo gem update --system
ruby:
	sudo yum -y install ruby
	sudo yum -y install ruby-irb
	sudo yum -y install ruby-devel
	sudo yum -y install ruby-rdoc
