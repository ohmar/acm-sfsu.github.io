PY=python
PELICAN=pelican
PELICANOPTS=

BASEDIR=$(CURDIR)
INPUTDIR=$(BASEDIR)/content
OUTPUTDIR=$(BASEDIR)/output
CONFFILE=$(BASEDIR)/pelicanconf.py
PUBLISHCONF=$(BASEDIR)/publishconf.py
OUTPUT_BRANCH=master
SOURCE_BRANCH=source

# for Sass
THEME_NAME=pelican-cait
SASS_IN=$(BASEDIR)/themes/$(THEME_NAME)/static/css/sass
SASS_OUT=$(BASEDIR)/themes/$(THEME_NAME)/static/css

# for Post and Page
TOPIC ?= awesome title
title ?= $(TOPIC)
POSTFILE = $(shell date "+$(INPUTDIR)/%Y-%m-%d-$(title).md" | sed -e y/\ /-/)
PAGEFILE = "$(INPUTDIR)/pages/$(TOPIC).md" | sed -e y/\ /-/
DATE = $(shell date +"%Y-%m-%d %R")

FTP_HOST=localhost
FTP_USER=anonymous
FTP_TARGET_DIR=/

SSH_HOST=localhost
SSH_PORT=22
SSH_USER=root
SSH_TARGET_DIR=/var/www

S3_BUCKET=my_s3_bucket

CLOUDFILES_USERNAME=my_rackspace_username
CLOUDFILES_API_KEY=my_rackspace_api_key
CLOUDFILES_CONTAINER=my_cloudfiles_container

DROPBOX_DIR=~/Dropbox/Public/

DEBUG ?= 0
ifeq ($(DEBUG), 1)
	PELICANOPTS += -D
endif

help:
	@echo 'Makefile for a pelican Web site                                        '
	@echo '                                                                       '
	@echo 'Usage:                                                                 '
	@echo '   make html                        (re)generate the web site          '
	@echo '   make sass                        generates css from sass dir        '
	@echo '   make all                         generates sass and html            '
#	@echo '   make regenerate                  regenerate files upon modification '
	@echo '   make regenerate_html             regenerate html when modified      '
	@echo '   make regenerate_sass             regenerates css from sass          '
	@echo '   make clean                       remove the generated files         '
	@echo '   make publish                     generate using production settings '
	@echo '   make serve [PORT=8000]           serve site at http://localhost:8000'
	@echo '   make devserver [PORT=8000]       start/restart develop_server.sh    '
	@echo '   make stopserver                  stop local server                  '
	@echo '   make ssh_upload                  upload the web site via SSH        '
	@echo '   make rsync_upload                upload the web site via rsync+ssh  '
	@echo '   make dropbox_upload              upload the web site via Dropbox    '
	@echo '   make ftp_upload                  upload the web site via FTP        '
	@echo '   make s3_upload                   upload the web site via S3         '
	@echo '   make cf_upload                   upload the web site via Cloud Files'
	@echo '   make github                      upload the web site via gh-pages   '
	@echo '   make post [title='mytitle']      begin a new post in INPUTDIR       '
	@echo '   make page                        create a new page in INPUTDIR/pages'
	@echo '                                                                       '
	@echo 'Set the DEBUG variable to 1 to enable debugging, e.g. make DEBUG=1 html'
	@echo '                                                                       '

html:
	$(PELICAN) $(INPUTDIR) -o $(OUTPUTDIR) -s $(CONFFILE) $(PELICANOPTS)

regenerate_html:
	$(PELICAN) -r $(INPUTDIR) -o $(OUTPUTDIR) -s $(CONFFILE) $(PELICANOPTS)

sass:
	sass --update $(SASS_IN):$(SASS_OUT)

regenerate_sass:
	sass --watch $(SASS_IN):$(SASS_OUT)

all: sass html

regenerate: regenerate_sass regnerate_html

clean:
	[ ! -d $(OUTPUTDIR) ] || rm -rf $(OUTPUTDIR)

serve:
ifdef PORT
	cd $(OUTPUTDIR) && $(PY) -m pelican.server $(PORT)
else
	cd $(OUTPUTDIR) && $(PY) -m pelican.server
endif

devserver:
ifdef PORT
	$(BASEDIR)/develop_server.sh restart $(PORT)
else
	$(BASEDIR)/develop_server.sh restart
endif

stopserver:
	kill -9 `cat pelican.pid`
	kill -9 `cat srv.pid`
	@echo 'Stopped Pelican and SimpleHTTPServer processes running in background.'

publish:
	$(PELICAN) $(INPUTDIR) -o $(OUTPUTDIR) -s $(PUBLISHCONF) $(PELICANOPTS)

ssh_upload: publish
	scp -P $(SSH_PORT) -r $(OUTPUTDIR)/* $(SSH_USER)@$(SSH_HOST):$(SSH_TARGET_DIR)

rsync_upload: publish
	rsync -e "ssh -p $(SSH_PORT)" -P -rvz --delete $(OUTPUTDIR)/ $(SSH_USER)@$(SSH_HOST):$(SSH_TARGET_DIR) --cvs-exclude

dropbox_upload: publish
	cp -r $(OUTPUTDIR)/* $(DROPBOX_DIR)

ftp_upload: publish
	lftp ftp://$(FTP_USER)@$(FTP_HOST) -e "mirror -R $(OUTPUTDIR) $(FTP_TARGET_DIR) ; quit"

s3_upload: publish
	s3cmd sync $(OUTPUTDIR)/ s3://$(S3_BUCKET) --acl-public --delete-removed

cf_upload: publish
	cd $(OUTPUTDIR) && swift -v -A https://auth.api.rackspacecloud.com/v1.0 -U $(CLOUDFILES_USERNAME) -K $(CLOUDFILES_API_KEY) upload -c $(CLOUDFILES_CONTAINER) .

github: publish
	ghp-import $(OUTPUTDIR)
	git push origin $(OUTPUT_BRANCH)

post:
ifneq ($(wildcard $(POSTFILE)),)
	@read -r -p "File $(title) already exists! Modify? (y/n):" REPLY; \
	[ $$REPLY = "y" ] || (echo Nothing done for post.; exit 1;)
	@sed 's/Modified:.*/Modified: $(DATE)/' $(POSTFILE) > $(POSTFILE).tmp
	@mv $(POSTFILE).tmp $(POSTFILE)
	@xdg-open $(POSTFILE) || open $(POSTFILE)
else 
	@echo "Title: $(title)" > $(POSTFILE)
	@echo "Date: $(DATE)" >> $(POSTFILE)
	@echo "Modified:" >> $(POSTFILE)
	@echo "Category:" >> $(POSTFILE)
	@echo "Tags:" >> $(POSTFILE)
	@echo "Slug: $(title)" >> $(POSTFILE)
	@echo "Authors: SFSU-ACM" >> $(POSTFILE)
	@echo "Authors_Sites: https://github.com/acm-sfsu" >> $(POSTFILE)
	@echo "Summary:" >> $(POSTFILE)
	@xdg-open $(POSTFILE) || open $(POSTFILE)
	@echo 'post successfully made at $(POSTFILE).' 
endif

page: 
	echo "Title: $(TOPIC)" >> $(PAGEFILE)
	echo "Date: $(DATE)" >> $(PAGEFILE)
	echo "Modified:" >> $(PAGEFILE)
	echo "Slug: $(TOPIC)" >> $(PAGEFILE)
	echo "Authors: SFSU-ACM" >> $(PAGEFILE)
	echo "Authors_Sites: https://github.com/acm-sfsu" >> $(PAGEFILE)
	echo "Summary:" >> $(PAGEFILE)
	xdg-open $(PAGEFILE)
	@echo 'page successfully made at $(PAGEFILE)'

.PHONY: html help clean regenerate serve devserver publish ssh_upload rsync_upload dropbox_upload ftp_upload s3_upload cf_upload github post page sass all regenerate_html regenerate_sass
