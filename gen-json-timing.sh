#!/usr/bin/env python
#-*- coding: UTF-8 -*-

# autor: Carlos Rueda
# date: 2016-07-01
# version: 1.1

##################################################################################
# version 1.0 release notes: extract data from MySQL and generate json
# Initial version
# Requisites: library python-mysqldb. To install: "apt-get install python-mysqldb"
##################################################################################


import MySQLdb
import logging, logging.handlers
import os
import json
import sys
import datetime
import calendar
import time

#### VARIABLES #########################################################
from configobj import ConfigObj
#config = ConfigObj('/opt/gen-json/gen-json-timing.properties')
config = ConfigObj('./gen-json-timing.properties')

INTERNAL_LOG_FILE = config['directory_logs'] + "/gen-json-timing.log"
LOG_FOR_ROTATE = 10

stage1_date = config['STAGE1_DATE']
stage1_url = config['STAGE1_URL']

PID = "/var/run/json-generator-timing"

from json import encoder
encoder.FLOAT_REPR = lambda o: format(o, '.4f')

 
########################################################################
# definimos los logs internos que usaremos para comprobar errores
log_folder = os.path.dirname(INTERNAL_LOG)

if not os.path.exists(log_folder):
	os.makedirs(log_folder)

try:
	logger = logging.getLogger('wrc-json-timing')
	loggerHandler = logging.handlers.TimedRotatingFileHandler(INTERNAL_LOG_FILE , 'midnight', 1, backupCount=10)
	formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
	loggerHandler.setFormatter(formatter)
	logger.addHandler(loggerHandler)
	logger.setLevel(logging.DEBUG)
except:
	print '------------------------------------------------------------------'
	print '[ERROR] Error writing log at %s' % INTERNAL_LOG_FILE
	print '[ERROR] Please verify path folder exits and write permissions'
	print '------------------------------------------------------------------'
	exit()
########################################################################

########################################################################
if os.access(os.path.expanduser(PID), os.F_OK):
        print "Checking if json generator is already running..."
        pidfile = open(os.path.expanduser(PID), "r")
        pidfile.seek(0)
        old_pd = pidfile.readline()
        # process PID
        if os.path.exists("/proc/%s" % old_pd) and old_pd!="":
			print "You already have an instance of the json generator running"
			print "It is running as process %s," % old_pd
			sys.exit(1)
        else:
			print "Trying to start json generator..."
			os.remove(os.path.expanduser(PID))

pidfile = open(os.path.expanduser(PID), 'a')
print "json generator started with PID: %s" % os.getpid()
pidfile.write(str(os.getpid()))
pidfile.close()
#########################################################################

def getUTC():
	t = calendar.timegm(datetime.datetime.utcnow().utctimetuple())
	return int(t)


def genTiming(url):
	headers = {"Content-type": "application/json"}	
	try:
		response = requests.get(url)
		#print "code:"+ str(response.status_code)
		#print "headers:"+ str(response.headers)
		#print "content:"+ str(response.text)
		timingXml = response.text
		e = xml.etree.ElementTree.parse(timingXml).getroot()
		for atype in e.findall('type'):
			print(atype.get('competitor'))

	except requests.ConnectionError as e:
		print "Error al llamar a la api:" + str(e)

genTiming(stage1_url)

#while True:
	
#	time.sleep(1)
