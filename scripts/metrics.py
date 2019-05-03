import subprocess
import os
import re
import time
from contextlib import suppress
from glob import glob
import logging


logger = logging.getLogger('metrics')


def read_file(path):
    logger.debug('read_file %s', path)
    with open(path) as file:
        return file.read()


def get_platform():
    s = read_file('/proc/cpuinfo')
    if 'ODROIDC' in s:
        return 'nc'
    if 'ODROID-XU' in s:
        return 'ep'
    return 'unknown'


def get_sys_uptime():
    fields = read_file('/proc/uptime').split()
    return int(float(fields[0]))


def get_dev_uptime(path):
    try:
        return int(time.time() - os.path.getctime(path))
    except FileNotFoundError:
        return 0


def get_dev_timestamp(path):
    try:
        return int(os.path.getctime(path))
    except FileNotFoundError:
        return 0


def get_dev_exists(path):
    return os.path.exists(path)


def get_net_metrics(iface):
    try:
        rx = int(read_file(os.path.join('/sys/class/net', iface, 'statistics/rx_bytes')))
        tx = int(read_file(os.path.join('/sys/class/net', iface, 'statistics/tx_bytes')))
    except FileNotFoundError:
        rx = 0
        tx = 0
    return rx, tx


def get_service_status(service):
    try:
        subprocess.check_output(['systemctl', 'is-active', service]).decode()
        return True
    except subprocess.CalledProcessError:
        return False


# can also have a log tail process watching all the wagman logs for events

def get_wagman_metrics(metrics):
    # optimization... doesn't bother with query if device missing.
    if not get_dev_exists('/dev/waggle_sysmon'):
        return

    with suppress(Exception):
        metrics['wagman', 'uptime'] = int(subprocess.check_output(['wagman-client', 'up']).decode())

    log = subprocess.check_output([
        'journalctl',                   # scan journal for
        '-u', 'waggle-wagman-driver',   # wagman driver logs
        '--since', '-90',               # from last 90s
        '-b',                           # from this boot only
        '-o', 'cat',                    # in compact form
    ]).decode()

    metrics['wagman', 'comm'] = ':wagman:' in log

    with suppress(Exception):
        nc, ep, cs = re.findall(r':fails (\d+) (\d+) (\d+)', log)[-1]
        metrics['wagman_fc', 'nc'] = int(nc)
        metrics['wagman_fc', 'ep'] = int(ep)
        metrics['wagman_fc', 'cs'] = int(cs)

    with suppress(Exception):
        wm, nc, ep, cs = re.findall(r':cu (\d+) (\d+) (\d+) (\d+)', log)[-1]
        metrics['wagman_cu', 'wm'] = int(wm)
        metrics['wagman_cu', 'nc'] = int(nc)
        metrics['wagman_cu', 'ep'] = int(ep)
        metrics['wagman_cu', 'cs'] = int(cs)

    with suppress(Exception):
        nc, ep, cs = re.findall(r':enabled (\d+) (\d+) (\d+)', log)[-1]
        metrics['wagman_enabled', 'nc'] = bool(nc)
        metrics['wagman_enabled', 'ep'] = bool(ep)
        metrics['wagman_enabled', 'cs'] = bool(cs)

    with suppress(Exception):
        ports = re.findall(r':vdc (\d+) (\d+) (\d+) (\d+) (\d+)', log)[-1]
        metrics['wagman_vdc', '0'] = int(ports[0])
        metrics['wagman_vdc', '1'] = int(ports[1])
        metrics['wagman_vdc', '2'] = int(ports[2])
        metrics['wagman_vdc', '3'] = int(ports[3])
        metrics['wagman_vdc', '4'] = int(ports[4])

    with suppress(Exception):
        metrics['wagman_hb', 'nc'] = 'nc heartbeat' in log
        metrics['wagman_hb', 'ep'] = 'gn heartbeat' in log
        metrics['wagman_hb', 'cs'] = 'cs heartbeat' in log

    log = subprocess.check_output([
        'journalctl',                   # scan journal for
        '-u', 'waggle-wagman-driver',   # wagman driver logs
        '--since', '-300',               # from last 5m
        '-b',                           # from this boot only
    ]).decode()

    # maybe we just schedule this service to manage its own sleep / monitoring timer
    # this would actually allow events to be integrated reasonably.
    metrics['wagman_stopping', 'nc'] = re.search(r'wagman:nc stopping', log) is not None
    metrics['wagman_stopping', 'ep'] = re.search(r'wagman:gn stopping', log) is not None
    metrics['wagman_stopping', 'cs'] = re.search(r'wagman:cs stopping', log) is not None

    metrics['wagman_starting', 'nc'] = re.search(r'wagman:nc starting', log) is not None
    metrics['wagman_starting', 'ep'] = re.search(r'wagman:gn starting', log) is not None
    metrics['wagman_starting', 'cs'] = re.search(r'wagman:cs starting', log) is not None

    metrics['wagman_killing', 'nc'] = re.search(r'wagman:nc killing', log) is not None
    metrics['wagman_killing', 'ep'] = re.search(r'wagman:gn killing', log) is not None
    metrics['wagman_killing', 'cs'] = re.search(r'wagman:cs killing', log) is not None

    # print(re.findall(r'wagman:(\S+) stopping (\S+)', log))
    # print(re.findall(r'wagman:(\S+) starting (\S+)', log))
    # print(re.findall(r'wagman:(\S+) killing', log))

def get_common_metrics(metrics):
    metrics['uptime'] = get_sys_uptime()
    metrics['time'] = int(time.time())
    metrics['running', 'rabbitmq'] = get_service_status('rabbitmq-server')
    rx, tx = get_net_metrics('eth0')
    metrics['net_lan', 'rx'] = rx
    metrics['net_lan', 'tx'] = tx


def check_ping(host):
    try:
        subprocess.check_output(['ping', '-c', '4', host])
        return True
    except Exception:
        return False

# should have a generic query interface and be able to just multi req against it.

def get_nc_metrics(metrics):
    metrics['ping_ep', 'up'] = int(check_ping('10.31.81.51'))
    metrics['ping_beehive', 'up'] = int(check_ping('beehive'))

    metrics['dev_wagman', 'up'] = get_dev_exists('/dev/waggle_sysmon')
    metrics['dev_coresense', 'up'] = get_dev_exists('/dev/waggle_coresense')
    metrics['dev_modem', 'up'] = get_dev_exists('/dev/attwwan')
    metrics['dev_wwan', 'up'] = get_dev_exists('/sys/class/net/ppp0')
    metrics['dev_lan', 'up'] = get_dev_exists('/sys/class/net/eth0')
    metrics['dev_mic', 'up'] = get_dev_exists('/dev/waggle_microphone')
    metrics['dev_samba', 'up'] = get_dev_exists('/dev/serial/by-id/usb-03eb_6124-if00')

    rx, tx = get_net_metrics('ppp0')
    metrics['net_wwan', 'rx'] = rx
    metrics['net_wwan', 'tx'] = tx

    get_wagman_metrics(metrics)

    metrics['running', 'coresense'] = get_service_status('waggle-plugin-coresense')


def get_ep_metrics(metrics):
    metrics['dev_bcam', 'up'] = get_dev_exists('/dev/waggle_cam_bottom')
    metrics['dev_tcam', 'up'] = get_dev_exists('/dev/waggle_cam_top')
    metrics['dev_mic', 'up'] = get_dev_exists('/dev/waggle_microphone')
    metrics['ping_nc', 'up'] = check_ping('10.31.81.10')


def get_metrics():
    metrics = {}

    get_common_metrics(metrics)

    platform = get_platform()

    if platform == 'nc':
        get_nc_metrics(metrics)
    if platform == 'ep':
        get_ep_metrics(metrics)

    return metrics


def main():
    import pprint
    pprint.pprint(get_metrics())


if __name__ == '__main__':
    main()
