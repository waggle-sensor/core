import subprocess
import os
import re
import time
from contextlib import suppress
from glob import glob


def read_file(path):
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
        active = True
    except subprocess.CalledProcessError:
        active = False
    return int(active)


def get_wagman_metrics(metrics):
    # optimization... doesn't bother with query if device missing.
    if get_dev_uptime('/dev/waggle_sysmon') == 0:
        return

    with suppress(Exception):
        metrics['wagman', 'uptime'] = int(subprocess.check_output(['wagman-client', 'up']).decode())

    log = subprocess.check_output(['journalctl', '-b', '-o', 'cat', '-u', 'waggle-wagman-driver', '--since', '-90']).decode()

    with suppress(Exception):
        nc, ep, cs = re.findall(r':fails (\d+) (\d+) (\d+)', log)[-1]
        metrics['wagman', 'fc', 'nc'] = int(nc)
        metrics['wagman', 'fc', 'ep'] = int(ep)
        metrics['wagman', 'fc', 'cs'] = int(cs)

    with suppress(Exception):
        wm, nc, ep, cs = re.findall(r':cu (\d+) (\d+) (\d+) (\d+)', log)[-1]
        metrics['wagman', 'cu', 'wm'] = int(wm)
        metrics['wagman', 'cu', 'nc'] = int(nc)
        metrics['wagman', 'cu', 'ep'] = int(ep)
        metrics['wagman', 'cu', 'cs'] = int(cs)

    with suppress(Exception):
        nc, ep, cs = re.findall(r':enabled (\d+) (\d+) (\d+)', log)[-1]
        metrics['wagman', 'enabled', 'nc'] = int(nc)
        metrics['wagman', 'enabled', 'ep'] = int(ep)
        metrics['wagman', 'enabled', 'cs'] = int(cs)

    with suppress(Exception):
        metrics['wagman', 'hb', 'nc'] = int('nc heartbeat' in log)
        metrics['wagman', 'hb', 'ep'] = int('gn heartbeat' in log)
        metrics['wagman', 'hb', 'cs'] = int('cs heartbeat' in log)


def get_common_metrics(metrics):
    metrics['uptime'] = get_sys_uptime()

    metrics['platform'] = get_platform()
    metrics['running', 'rabbitmq'] = get_service_status('rabbitmq-server')

    rx, tx = get_net_metrics('eth0')
    metrics['net', 'lan', 'rx'] = rx
    metrics['net', 'lan', 'tx'] = tx


def get_nc_metrics(metrics):
    metrics['nc', 'wagman', 'uptime'] = get_dev_uptime('/dev/waggle_sysmon')

    cspath = (glob('/dev/serial/by-id/*Due*')
                or ['/dev/serial/by-id/usb-Arduino_LLC_Arduino_Due-if00'])[0]
    metrics['nc', 'coresense', 'uptime'] = get_dev_uptime(cspath)

    metrics['nc', 'modem', 'uptime'] = get_dev_uptime('/dev/attwwan')

    # TODO split expected files into config file.
    # metrics['nc', 'wwan', 'uptime'] = get_dev_timestamp('/sys/class/net/ppp0')
    # metrics['nc', 'lan', 'uptime'] = get_dev_timestamp('/sys/class/net/eth0')
    metrics['nc', 'wwan', 'uptime'] = get_dev_uptime('/sys/class/net/ppp0')
    metrics['nc', 'lan', 'uptime'] = get_dev_uptime('/sys/class/net/eth0')
    metrics['nc', 'mic', 'uptime'] = get_dev_uptime('/dev/waggle_microphone')
    metrics['nc', 'samba', 'uptime'] = get_dev_uptime('/dev/serial/by-id/usb-03eb_6124-if00')

    rx, tx = get_net_metrics('ppp0')
    metrics['net', 'wwan', 'rx'] = rx
    metrics['net', 'wwan', 'tx'] = tx

    get_wagman_metrics(metrics)

    metrics['running', 'coresense'] = get_service_status('waggle-plugin-coresense')


def get_ep_metrics(metrics):
    metrics['ep_bcam_uptime'] = get_dev_uptime('/dev/waggle_cam_bottom')
    metrics['ep_tcam_uptime'] = get_dev_uptime('/dev/waggle_cam_top')
    metrics['ep_mic_uptime'] = get_dev_uptime('/dev/waggle_microphone')


def get_metrics():
    metrics = {}

    get_common_metrics(metrics)

    if metrics['platform'] == 'nc':
        get_nc_metrics(metrics)
    if metrics['platform'] == 'ep':
        get_ep_metrics(metrics)

    return metrics


def main():
    import pprint
    pprint.pprint(get_metrics())


if __name__ == '__main__':
    main()
