import requests
from requests.exceptions import HTTPError
import pandas as pd
import os
from dotenv import load_dotenv
#============== config ===================
load_dotenv()
#======= resource_id ===========



def get_json(rs_id):
    param = {
    "resource_id": rs_id,
    "limit": "1"
    }
    url = os.getenv("base_url")
    if not url:
        return ValueError("url missing")
    total_rec = requests.get(url, params=param)
    total_rec.raise_for_status()
    data = total_rec.json()['results']['total']
    return print(data)

if __name__=="__main__":
    mot = os.getenv("mot_submodel")
    get_json(mot)