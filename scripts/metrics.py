import subprocess
import os
import re
import time
from contextlib import suppress
from glob import glob
import logging
import configparser


logger = logging.getLogger('metrics')


def read_file(path):
    logger.debug('read_file %s', path)
    with open(path) as file:
        return file.read()


def read_section_keys(config, section):
    try:
        return list(config[section])
    except KeyError:
        return []


def read_config_file(path):
    logger.debug('reading config %s', path)

    config = configparser.ConfigParser(allow_no_value=True)
    config.read(path)

    return {
        'devices': read_section_keys(config, 'devices'),
        'network': read_section_keys(config, 'network'),
        'ping': read_section_keys(config, 'ping'),
    }


def get_sys_uptime():
    fields = read_file('/proc/uptime').split()
    return int(float(fields[0]))


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

def get_wagman_metrics(config, metrics):
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


def check_ping(host):
    try:
        subprocess.check_output(['ping', '-c', '4', host])
        return True
    except Exception:
        return False

def get_sys_metrics(config, metrics):
    metrics['uptime'] = get_sys_uptime()
    metrics['time'] = int(time.time())
    metrics['running', 'rabbitmq'] = get_service_status('rabbitmq-server')
    metrics['running', 'coresense'] = get_service_status('waggle-plugin-coresense')


devices = {
    'wagman': '/dev/waggle_sysmon',
    'coresense': '/dev/waggle_coresense',
    'modem': '/dev/attwwan',
    'wwan': '/sys/class/net/ppp0',
    'lan': '/sys/class/net/eth0',
    'mic': '/dev/waggle_microphone',
    'samba': '/dev/serial/by-id/usb-03eb_6124-if00',
    'bcam': '/dev/waggle_cam_bottom',
    'tcam': '/dev/waggle_cam_top',
}


def get_device_metrics(config, metrics):
    for device in config['devices']:
        try:
            path = devices[device]
        except KeyError:
            logger.warning('no device "%s"', device)
            continue

        metrics['dev_' + device, 'up'] = get_dev_exists(path)


hosts = {
    'beehive': 'beehive',
    'nc': '10.31.81.10',
    'ep': '10.31.81.51',
}


def get_ping_metrics(config, metrics):
    for name in config.get('ping', []):
        try:
            host = hosts[name]
        except KeyError:
            logger.warning('no ping host "%s"', name)
            continue

        metrics['ping_' + name, 'up'] = check_ping(host)


ifaces = {
    'wwan': 'ppp0',
    'lan': 'eth0',
}


def get_network_metrics(config, metrics):
    for name in config['network']:
        try:
            iface = ifaces[name]
            logger.warning('no network interface "%s"', iface)
        except KeyError:
            continue

        rx, tx = get_net_metrics(iface)
        metrics['net_' + name, 'rx'] = rx
        metrics['net_' + name, 'tx'] = tx


def get_metrics_for_config(config):
    metrics = {}

    get_sys_metrics(config, metrics)
    get_device_metrics(config, metrics)

    if 'wagman' in config['devices']:
        get_wagman_metrics(config, metrics)

    get_ping_metrics(config, metrics)
    get_network_metrics(config, metrics)

    return metrics


def main():
    import pprint
    config = read_config_file('/wagglerw/metrics.config')
    pprint.pprint(get_metrics_for_config(config))


if __name__ == '__main__':
    main()
