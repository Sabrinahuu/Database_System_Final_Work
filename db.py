import pymysql
from config import DB_CONFIG

def get_conn():
    return pymysql.connect(**DB_CONFIG)