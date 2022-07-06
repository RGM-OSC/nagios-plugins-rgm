#!/usr/bin/python3

from turtle import right
import requests

class AzureApi:
    def __init__(self, id, secret):
        """
            Initialisation from Azure API
        """
        self.data = {"grant_type": "client_credentials",
                "client_id": id,
                "client_secret": secret,
                "resource": "https://management.azure.com/" 
        }
        self.headers = {"Content-Type": "application/json"}
    
    def get_token(self, directory, put_in_header = True):
        """
            Get token from Azure API
        """
        url = 'https://login.microsoftonline.com/{directory}/oauth2/token?api-version=1.0'.format(directory=directory)
        response = requests.post(url, data=self.data)
        if response.status_code != 200:
            raise TokenException('Error getting token... Status code {response.status_code}'.format(response=response))
        self.token = response.json()['access_token']
        if put_in_header:
            try:
                self.headers.update({"Authorization": 'Bearer {self.token}'.format(self=self)})
            except Exception as e:
                raise TokenException('Error on updating headers')
        else:
            return self.token

    def get_info(self, url, headers={}):
        """
            Get info from Azure API
        """
        try:
            self.headers.update(headers)
            return requests.get(url, headers=self.headers).json()
        except Exception as e:
            raise Exception(e)

class TokenException(Exception):
    """
    Exception Class for Token
    """
    def __init__(self,message):
        self.message = message
    def __str__(self):
        return 'Error : Token Exception {message}'.format(message = self.message)