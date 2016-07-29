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


import logging, logging.handlers
import os
import json
import sys
import datetime
import calendar
import requests
import time
import xml.etree.ElementTree

from xml.dom import minidom

#### VARIABLES #########################################################
from configobj import ConfigObj
config = ConfigObj('./gen-json-timing.properties')

INTERNAL_LOG_FILE = config['directory_logs'] + "/gen-json-timing.log"
LOG_FOR_ROTATE = 10

entry_url = config['ENTRY_URL']

stages_date = [config['S24_DATE'], config['S23_DATE'], config['S22_DATE'], config['S21_DATE'], config['S20_DATE'], config['S19_DATE'], config['S18_DATE'], config['S17_DATE'], config['S16_DATE'], config['S15_DATE'], config['S14_DATE'], config['S13_DATE'], config['S12_DATE'], config['S11_DATE'], config['S10_DATE'], config['S9_DATE'], config['S9_DATE'], config['S7_DATE'], config['S6_DATE'], config['S5_DATE'], config['S4_DATE'], config['S3_DATE'], config['S2_DATE'], config['S1_DATE']]
stages_url = [config['S24_URL'],config['S23_URL'],config['S22_URL'],config['S21_URL'],config['S20_URL'],config['S19_URL'],config['S18_URL'],config['S17_URL'],config['S16_URL'],config['S15_URL'],config['S14_URL'],config['S13_URL'],config['S12_URL'],config['S11_URL'],config['S10_URL'],config['S9_URL'],config['S8_URL'],config['S7_URL'],config['S6_URL'],config['S5_URL'],config['S4_URL'],config['S3_URL'],config['S2_URL'],config['S1_URL']]

PID = "/var/run/json-generator-timing"

from json import encoder
encoder.FLOAT_REPR = lambda o: format(o, '.4f')

entryList = {}

########################################################################
# definimos los logs internos que usaremos para comprobar errores
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

class Competitor(object): 
    nr = "" 
    stime = "" 
    epoch_time = 0 

def getUTC():
	t = calendar.timegm(datetime.datetime.utcnow().utctimetuple())
	return int(t)

def getEpoch(isoDate):
	return ((calendar.timegm(time.strptime(isoDate, '%Y-%m-%dT%H:%M:%SZ'))) * 1000) - 7800000

def getEpochTime(isoDate):
	return (calendar.timegm(time.strptime(isoDate, '%H:%M.%S')))

def getActualStage(stages_epoch):
	epoch_time = int(time.time()) * 1000
	# corregir para el rally
	epoch_time = epoch_time + 3600000
	index = 0
	for s in stages_epoch:
		#print "--->" + str(s)
		if (epoch_time > (s - 300000)):
			#print s
			return index
		index += 1
	return 23


def getEntryList():
	headers = {"Content-type": "application/json"}	
	try:
		response = requests.get(entry_url)
		entryXml = response.text
		#xmldoc = minidom.parseString(entryXml)
		xmldoc = minidom.parseString(u'{0}'.format(entryXml).encode('utf-8'))
		itemlist = xmldoc.getElementsByTagName('entry')
		#print itemlist
		for s in itemlist:
			nr = s.attributes['nr'].value
			driverName = s.attributes['driverName'].value
			driverSurname = s.attributes['driverSurname'].value
			entryList[str(nr)] = driverName + " " + driverSurname

	except requests.ConnectionError as e:
		print "Error al llamar a la api:" + str(e)

def genTiming(url):
	array_list = []
	competitor_list = []
	result_list = []

	headers = {"Content-type": "application/json"}	
	try:
		response = requests.get(url)
		timingXml = response.text

		#xmldoc = minidom.parseString(timingXml)
		xmldoc = minidom.parseString(u'{0}'.format(timingXml).encode('utf-8'))
		itemlistSplit = xmldoc.getElementsByTagName('splitTimes')
		stageId = itemlistSplit[0].attributes['stage'].value
		stageName = itemlistSplit[0].attributes['location'].value
		stageTitle = "SS" + stageId + " - " + stageName
		stage = {"type": "stage_data", "properties": {"stageName": stageTitle }}
		array_list.append(stage)

		itemlistCompetitor = xmldoc.getElementsByTagName('competitor')
		for s in itemlistCompetitor:
			pos = s.attributes['pos'].value
			nr = s.attributes['nr'].value
			stime = s.attributes['time'].value

			if (stime != ""):
				competitor = Competitor() 
				competitor.nr = nr
				competitor.stime = stime
				competitor.epoch_time = getEpochTime(stime)

				competitor_list.append(competitor)
			'''
			try:
				competitor = {"type": "car_timing", "properties": {"pos": int(pos), "nr": str(nr), "driver": entryList[str(nr)], "diff": stime}}
			except e:
				competitor = {"type": "car_timing", "properties": {"pos": 0, "nr": 0, "driver": entryList[str(nr)], "diff": '--'}}
			array_list.append(competitor)
			'''
		result_list = sorted(competitor_list, key=lambda competitor: competitor.epoch_time) 
		position = 1
		for r in result_list:
			competitorOrdered = {"type": "car_timing", "properties": {"pos": position, "nr": r.nr, "driver": entryList[str(r.nr)], "diff": r.stime}}
			array_list.append(competitorOrdered)
			position += 1

		with open('/var/www2/timing.json', 'w') as outfile:		
		#with open('/Applications/MAMP/htdocs/wrc-hs/timing.json', 'w') as outfile:
		#with open('./timing.json', 'w') as outfile:
			json.dump(array_list, outfile)

	except requests.ConnectionError as e:
		print "Error al llamar a la api:" + str(e)

getEntryList()
stages_epoch = [getEpoch(stages_date[0]),getEpoch(stages_date[1]),getEpoch(stages_date[2]),getEpoch(stages_date[3]),getEpoch(stages_date[4]),getEpoch(stages_date[5]),getEpoch(stages_date[6]),getEpoch(stages_date[7]),getEpoch(stages_date[8]),getEpoch(stages_date[9]),getEpoch(stages_date[10]),getEpoch(stages_date[11]),getEpoch(stages_date[12]),getEpoch(stages_date[13]),getEpoch(stages_date[14]),getEpoch(stages_date[15]),getEpoch(stages_date[16]),getEpoch(stages_date[17]),getEpoch(stages_date[18]),getEpoch(stages_date[19]),getEpoch(stages_date[20]),getEpoch(stages_date[21]),getEpoch(stages_date[22]),getEpoch(stages_date[23])]


indexStage = getActualStage(stages_epoch)
print indexStage
print stages_url[indexStage]
genTiming(stages_url[indexStage])
#while True:
#	indexStage = getActualStage(stages_epoch)
#	genTiming(stages_url[indexStage])
#	time.sleep(1)
