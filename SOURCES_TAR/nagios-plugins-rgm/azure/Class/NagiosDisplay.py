#!/usr/bin/python3

from datetime import datetime

class NagiosDisplay:
    def __init__(self, *args, warning=0, critical=0, **kwargs):
        self.fields = {}
        for name in args:
            self.fields[name] = {
                'warning': warning,
                'critical': critical,
                'value': 0
            }
        for name, value in kwargs.items():
            self.fields[name] = {
                'warning': value['warning'] if 'warning' in value else warning,
                'critical': value['critical'] if 'critical' in value else critical,
                'value': value['value'] if 'value' in value else 0
            }
        self.update_return_code()
    def give_values(self, **kwargs):
        for name, value in kwargs.items():
            self.fields[name] = {
                'warning': self.warning,
                'critical': self.critical,
                'value': value
            }
        self.update_return_code()

    def update_return_code(self):
        self.return_code = 0
        for name in self.fields.keys():
            values = self.fields[name]
            if values['critical'] is not None and values['value'] >= values['critical']:
                self.return_code = max(self.return_code, 2)
            elif values['warning'] is not None and values['value'] >= values['warning']:
                self.return_code = max(self.return_code, 1)
            else:
                self.return_code = max(self.return_code, 0)

    def __str__(self):
        date = datetime.now().strftime('%m/%d %H:%M')
        output = '{return_code} ({date}): '.format(return_code=nagios_exit_codes[self.return_code], date=date)
        for i in range(len(self.fields)):
            name = list(self.fields.keys())[i]
            values = self.fields[name]
            output += '{name}={value} '.format(name=name, value=values['value'])
            if i < len(self.fields.keys()) - 1:
                output += '- '
        output += '| '
        for name in self.fields.keys():
            values = self.fields[name]
            if values['warning'] is None and values['critical'] is None:
                output += "'{name}'={value};;;; ".format(name=name, value=values['value'])
            elif values['warning'] is None:
                output += "'{name}'={value};;{critical};;;; ".format(name=name, value=values['value'], critical=values['critical'])
            elif values['critical'] is None:
                output += "'{name}'={value};{warning};;;; ".format(name=name, value=values['value'], warning=values['warning'])
            else:
                output += "'{name}'={value};{warning};{critical};;;; ".format(name=name, value=values['value'], warning=str(values['warning']), critical=str(values['critical']))
        return output

nagios_exit_codes = {
    0: 'OK',
    1: 'WARNING',
    2: 'CRITICAL',
    3: 'UNKNOWN'
}

def print_error(message=''):
    return_code = 3
    print('{return_code}: Error... {message}'.format(return_code=nagios_exit_codes[return_code], message=message))
    exit(return_code)

if __name__ == '__main__':
    print(NagiosDisplay())
    print(NagiosDisplay('test1', 'test2', 'test3'))
    print(NagiosDisplay('test1', 'test2', warning=1, critical=2))
    print(NagiosDisplay(test1={'warning': 1, 'critical': 2}, test2={'warning': 3, 'critical': 4}))
    nag = NagiosDisplay()
    nag.warning = 1
    nag.critical = 2
    nag.give_values(test1=1, test2=2)
    print(nag)
    nag.fields['test2']['critical'] = 3
    nag.update_return_code()
    print(nag)
    print(NagiosDisplay(test1={'warning': None, 'critical': None, 'value':1}))
    print(NagiosDisplay(test1={'warning': 1, 'critical': None, 'value': 1}, test2={'warning': None, 'critical': 2, 'value': 2}))