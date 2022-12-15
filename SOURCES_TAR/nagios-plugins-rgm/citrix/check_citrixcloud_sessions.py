#!/usr/bin/python3

import argparse
from NagiosClasses import CitrixApi, NagiosDisplay

parser = argparse.ArgumentParser(description='Check Citrix Sessions status')
parser.add_argument('-u','--username', help='Client ID', required=True)
parser.add_argument('-s','--secret', help='Client Secret', required=True)
parser.add_argument('-C','--customer', help='Customer ID', required=True)
parser.add_argument('-c', '--critical', type=int, help='Defautl critical threshold', default=None)
parser.add_argument('-w', '--warning', type=int, help='Default warning threshold', default=None)
parser.add_argument('-ca', '--critical-active', type=int, help='Critical threshold of active sessions')
parser.add_argument('-wa', '--warning-active', type=int, help='Warning threshold of active sessions')
parser.add_argument('-cc', '--critical-concurrent', type=int, help='Critical threshold of concurrent sessions')
parser.add_argument('-wc', '--warning-concurrent', type=int, help='Warning threshold of concurrent sessions')
parser.add_argument('-cd', '--critical-disconnected', type=int, help='Critical threshold of disconnected sessions')
parser.add_argument('-wd', '--warning-disconnected', type=int, help='Warning threshold of disconnected sessions')
parser.add_argument('-v', '--verbose', help='Verbose output', action='store_true')
args = parser.parse_args()

client_id = args.username
client_secret = args.secret
customer_id = args.customer

critical_active = args.critical_active if args.critical_active else args.critical
warning_active = args.warning_active if args.warning_active else args.warning
critical_concurrent = args.critical_concurrent if args.critical_concurrent else args.critical
warning_concurrent = args.warning_concurrent if args.warning_concurrent else args.warning
critical_disconnected = args.critical_disconnected if args.critical_disconnected else args.critical
warning_disconnected = args.warning_disconnected if args.warning_disconnected else args.warning

api = CitrixApi.CitrixApi(client_id, client_secret, customer_id)

try:
    print('Authenticating...') if args.verbose else None
    api.get_token()
    api.get_my_instance_id()
    print('Authenticated!') if args.verbose else None
    
    # Get sessions
    print('Getting sessions...') if args.verbose else None
    sessions = api.get_info("https://api-us.cloud.com/cvad/manage/sessions")['Items']

    concurrent_sessions = len(sessions)
    active_sessions = 0
    disconnected_sessions = 0
    for session in sessions:
        session_id = session['Id']
        url = 'https://api-us.cloud.com/cvad/manage/sessions/{session_id}'.format(session_id=session_id)
        res = api.get_info(url)
        if res['State'] == 'Active':
            active_sessions += 1
        elif res['State'] == 'Disconnected':
            disconnected_sessions += 1

    if args.verbose:
        msg = '{concurrent_sessions} concurrent sessions, {active_sessions} active sessions, {disconnected_sessions} disconnected sessions'.format(concurrent_sessions=concurrent_sessions, active_sessions=active_sessions, disconnected_sessions=disconnected_sessions)
        print(msg)
    
    nag = NagiosDisplay.NagiosDisplay(
        Concurrent_sessions={'critical':critical_concurrent, 'warning':warning_concurrent, 'value':concurrent_sessions},
        Active_sessions={'critical':critical_active, 'warning':warning_active, 'value':active_sessions},
        Disconnected_sessions={'critical':critical_disconnected, 'warning':warning_disconnected, 'value':disconnected_sessions}
    )
    print(nag)
except Exception as e:
    NagiosDisplay.NagiosDisplay().print_error('Exception: {e}'.format(e=e))