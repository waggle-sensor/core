#!/usr/bin/python3

import time
import logging
import os
import subprocess
import waggle.logging
import json
import pyinotify
from pyinotify import WatchManager, Notifier, ProcessEvent, EventsCodes

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# beehive_reporter = waggle.logging.getLogger('monitor-filesystem')

def get_monitor_target(path='/etc/waggle/'):
	config_file = 'monitor-filesystem.conf'
	targets = []
	ignorances = []

	if not os.path.isfile(path+config_file):
		logging.error('Config file not found in %s' % path+config_file)
		logging.error('Please reconfigure nodecontroller')
		return []

	with open(path+config_file, 'r') as file:
		for line in file:
			line = line.strip()
			if '#' in line or line == '':
				continue

			if os.path.isfile(line[1:]) or os.path.isdir(line[1:]):
				if line[0] == 'A':
					targets.append(line[1:].strip())
				elif line[0] == 'I':
					ignorances.append(line[1:].strip())
				else:
					pass
			else:
				logging.error('Cannot watch the path: %s' % line[1:])			

	return targets, ignorances

class PTmp(ProcessEvent):
	def __init__(self, ignore_list):
		self.ignorances = ignore_list

	def report(self, event):
		global logging

		ignore = [True for i in self.ignorances if event.path == i]
		if ignore == []:
			logging.info('%s has been changed: %s' % (event.pathname, event.maskname))

	def process_IN_ATTRIB(self, event):
		self.report(event)

	def process_IN_DELETE(self, event):
		self.report(event)

	def process_IN_MODIFY(self, event):
		self.report(event)

	def process_IN_CLOSE_WRITE(self, event):
		self.report(event)

	def process_IN_DELETE_SELF(self, event):
		self.report(event)

if __name__ == "__main__":
	logging.info('Waggle filesystem monitor started...')

	targets, ignorances = get_monitor_target()
	logging.info('Waggle filesystem monitor will monitor the following files/folders')
	for target in targets:
		logging.info('....%s' % target)

	wm = WatchManager()
	mask = pyinotify.IN_DELETE | pyinotify.IN_ATTRIB | pyinotify.IN_MODIFY | pyinotify.IN_CLOSE_WRITE | pyinotify.IN_DELETE_SELF  # watched events

	notifier = Notifier(wm, PTmp(ignorances))
	wdd = wm.add_watch(targets, mask, rec=True)

	while True:
		try:
			notifier.process_events()
			if notifier.check_events():
				notifier.read_events()
		except:
			notifier.stop()
			break