import requests
import datetime
import pandas as pd

def round_value(value):
    return round(value * 1000) / 1000

def fetch_yahoo_sorted_results(ticker):
    now = round(datetime.datetime.now().timestamp())  # timestamp in seconds
    start = round(datetime.datetime(2019, 1, 1).timestamp())  # timestamp in seconds

    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}"
    payload = {"period1": start, "period2": now, "interval": "1mo", "lang": "en-US", "region": "GB"}
    # There is issue with 429 error in Yahoo API that does not allow to fetch using Python requests module, so rewriting user agent to curl should help
    headers = {"Accept": "*/*", "User-Agent": "curl/7.68.0"}

    res = requests.get(url, params=payload, headers=headers)

    chart = res.json()['chart']['result'][0]

    indicators = chart['indicators']['adjclose'][0]['adjclose'][:-1]  # last day data not needed

    data = []
    for index, close in enumerate(indicators):
        date = datetime.datetime.fromtimestamp(chart['timestamp'][index])
        data.append({
            'date': f"{date.year}-{str(date.month).zfill(2)}-01",
            'year': date.year,
            'month': date.month,
            'value': round_value(close),
            'index': None  # will be calculated later
        })

    data.sort(key=lambda x: x['date'])  # sort by date

    first_period_value = data[0]['value']

    # calculate index comparing to the first period
    for el in data:
        el['index'] = round_value(el['value'] / first_period_value)

    return data


gld = fetch_yahoo_sorted_results("GLD")
btc = fetch_yahoo_sorted_results("BTC-USD")
ixn = fetch_yahoo_sorted_results("IXN")
spx = fetch_yahoo_sorted_results("%5ESPX")

# all indicators should be sorted by date field already so that we can find matching values by index
result = []
for index, el in enumerate(gld):
    result.append({
        'date': el['date'],
        'year': el['year'],
        'month': el['month'],
        'gldValue': el['value'],
        'gldIndex': el['index'],
        'btcValue': btc[index]['value'] if index < len(btc) else None,
        'btcIndex': btc[index]['index'] if index < len(btc) else None,
        'ixnValue': ixn[index]['value'] if index < len(ixn) else None,
        'ixnIndex': ixn[index]['index'] if index < len(ixn) else None,
        'spxValue': spx[index]['value'] if index < len(spx) else None,
        'spxIndex': spx[index]['index'] if index < len(spx) else None,
    })

# generate csv
df = pd.DataFrame(result)
csv = df.to_csv(index=False, header=[
    "Date", "Year", "Month", "GLD, USD", "GLD index",
    "BTC, USD", "BTC index", "IXN, USD", "IXN index", "S&P (SPX), USD", "S&P index"
])

print(csv)