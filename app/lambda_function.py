import json, logging
import urllib3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

http = urllib3.PoolManager()

def send(text):
    apiToken = ''
    chatID   = ''
    apiURL   = f'https://api.telegram.org/bot{apiToken}/sendMessage'

    try:
        message = {'chat_id': chatID, 'parse_mode': 'html', 'text': text}
        message = json.dumps(message).encode("utf-8")
        return http.request("POST", apiURL, headers={'Content-Type': 'application/json'}, body=message)
    except Exception as e:
        return e

def getAlarm(message):
    alarm = dict()

    alarm['name'] = message['AlarmName']
    alarm['description'] = message['AlarmDescription']
    alarm['reason'] = message['NewStateReason']
    alarm['region'] = message['Region']
    alarm['instance_id'] = message['Trigger']['Dimensions'][0]['value']
    alarm['state'] = message['NewStateValue']
    alarm['previous_state'] = message['OldStateValue']

    return alarm

def lambda_handler(event, context):
    logger.info(event)

    sns_mgs = json.loads(event["Records"][0]["Sns"]["Message"])
    alarm   = getAlarm(sns_mgs)
    
    msg = "*** ALERT ***\n\n"

    if alarm['state'] == 'ALARM':
        msg += '<b>Region:</b> ' + alarm['region']  + "\n";
        msg += '<b>Alarm:</b> ' + alarm['name'] + "\n";
        msg += '<b>Description:</b> ' + alarm['description'] + "\n\n";
        msg += alarm['reason'];
    elif alarm['previous_state'] == 'ALARM' and alarm['state'] == 'OK':
        msg += '<b>Region:</b> ' + alarm['region']  + "\n";
        msg += '<b>Solved:</b> ' + alarm['name']  + "\n";
        msg += '<b>Description:</b> ' + alarm['description'];

    response = send(msg)

    return {
        "status_code": response.status,
        "response": response.data,
    }