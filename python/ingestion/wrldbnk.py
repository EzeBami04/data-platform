import requests
from requests.exceptions import HTTPError
import pandas as pd
import logging 
logging.basicConfig(level=logging.INFO)

#======== config =====================
url = "https://search.worldbank.org/api/v3/wds?format=json&qterm=wind%20turbine&fl=docdt,count"

def get_data():
    try:
        resp = requests.get(url, params={"limit": 1})
        resp.raise_for_status()
        data = resp.json()
        total_rec = int(data['total'])
        docs = (data.get('documents'))
        msdoc = {}
        rec = 0
        
        # while True:
        #     for docs in data:
        #         id = docs.get('id')
        #     rec += 1
        #     if rec == total_rec:
        #         break

        return print(data)
    except HTTPError as e:
        print(f"{e}")

if __name__ == "__main__":
    get_data()