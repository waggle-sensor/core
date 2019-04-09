# ANL:waggle-license
# This file is part of the Waggle Platform.  Please see the file
# LICENSE.waggle.txt for the legal details of the copyright and software
# license.  For more details on the Waggle project, visit:
#          http://www.wa8.gl
# ANL:waggle-license
import subprocess
# ANL:waggle-license
#  This file is part of the Waggle Platform.  Please see the file
#  LICENSE.waggle.txt for the legal details of the copyright and software
#  license.  For more details on the Waggle project, visit:
#           http://www.wa8.gl
# ANL:waggle-license


def add_user(username, password):
    return subprocess.check_output([
        'rabbitmqctl',
        'add_user',
        username,
        password,
    ])


def change_password(username, password):
    return subprocess.check_output([
        'rabbitmqctl',
        'change_password',
        username,
        password,
    ])


def set_permissions(username, configure, read, write):
    return subprocess.check_output([
        'rabbitmqctl',
        'set_permissions',
        username,
        configure,
        write,
        read,
    ])


def delete_user(username):
    return subprocess.check_output([
        'rabbitmqctl',
        'delete_user',
        username,
    ])
