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
        'services': read_section_keys(config, 'services'),
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

    s = read_file('/proc/meminfo')
    metrics['mem_total'] = int(re.search(r'MemTotal:\s*(\d+)\s*kB', s).group(1)) * 1024
    metrics['mem_free'] = int(re.search(r'MemFree:\s*(\d+)\s*kB', s).group(1)) * 1024

    s = read_file('/proc/loadavg')
    fs = s.split()
    metrics['loadavg1'] = float(fs[0])
    metrics['loadavg5'] = float(fs[1])
    metrics['loadavg15'] = float(fs[2])


device_table = {
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
    for name in config['devices']:
        if name not in device_table:
            logger.warning('no device "%s"', name)
            continue

        metrics['dev_' + name, 'up'] = get_dev_exists(device_table[name])


ping_table = {
    'beehive': 'beehive',
    'nc': '10.31.81.10',
    'ep': '10.31.81.51',
}


def get_ping_metrics(config, metrics):
    for name in config['ping']:
        if name not in ping_table:
            logger.warning('no ping host "%s"', name)
            continue

        metrics['ping_' + name, 'up'] = check_ping(ping_table[name])


network_table = {
    'wwan': 'ppp0',
    'lan': 'eth0',
}


def get_network_metrics(config, metrics):
    for name in config['network']:
        if name not in network_table:
            logger.warning('no network interface "%s"', name)
            continue

        rx, tx = get_net_metrics(network_table[name])
        metrics['net_' + name, 'rx'] = rx
        metrics['net_' + name, 'tx'] = tx


service_table = {
    'rabbitmq': 'rabbitmq-server',
    'coresense': 'waggle-plugin-coresense',
}

def get_service_metrics(config, metrics):
    for name in config['services']:
        if name not in service_table:
            logger.warning('no service "%s"', name)
            continue

        metrics['running', name] = get_service_status(service_table[name])


def get_metrics_for_config(config):
    metrics = {}

    get_sys_metrics(config, metrics)
    get_device_metrics(config, metrics)

    if 'wagman' in config['devices']:
        get_wagman_metrics(config, metrics)

    get_ping_metrics(config, metrics)
    get_network_metrics(config, metrics)
    get_service_metrics(config, metrics)

    return metrics


def main():
    import pprint
    config = read_config_file('/wagglerw/metrics.config')
    pprint.pprint(get_metrics_for_config(config))


if __name__ == '__main__':
    main()
