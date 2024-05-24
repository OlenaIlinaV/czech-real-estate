import math
import pprint

# https://www.czso.cz/csu/czso/inflation_rate
copied_inflation_cz = """2019	2.2	2.3	2.4	2.4	2.5	2.5	2.6	2.6	2.6	2.7	2.7	2.8
2020	2.9	3.0	3.1	3.1	3.1	3.1	3.2	3.2	3.3	3.3	3.2	3.2
2021	3.0	2.9	2.8	2.8	2.8	2.8	2.8	2.8	3.0	3.2	3.5	3.8
2022	4.5	5.2	6.1	7.0	8.1	9.4	10.6	11.7	12.7	13.5	14.4	15.1
2023	15.7	16.2	16.4	16.2	15.8	15.1	14.3	13.6	12.7	12.1	11.4	10.7
2024	9.4	8.2	7.1	6.3"""

# https://www.usinflationcalculator.com/inflation/current-inflation-rates/
copied_inflation_us = """2024	3.1	3.2	3.5	3.4
2023	6.4	6.0	5.0	4.9	4.0	3.0	3.2	3.7	3.7	3.2	3.1	3.4	4.1
2022	7.5	7.9	8.5	8.3	8.6	9.1	8.5	8.3	8.2	7.7	7.1	6.5	8.0
2021	1.4	1.7	2.6	4.2	5.0	5.4	5.4	5.3	5.4	6.2	6.8	7.0	4.7
2020	2.5	2.3	1.5	0.3	0.1	0.6	1.0	1.3	1.4	1.2	1.2	1.4	1.2
2019	1.6	1.5	1.9	2.0	1.8	1.6	1.8	1.7	1.7	1.8	2.1	2.3	1.8"""

def parse_inflation(copied_text):
    data = []
    for year_row in copied_text.split("\n"):
        year, *values = year_row.split("\t")
        for index, inflation in enumerate(values[:12]): # US inflation has 13th element with average inflation per year
            data.append({
                "date": f"{year}-{str(index + 1).zfill(2)}-01",
                "year": int(year),
                "month": index + 1,
                "inflation": inflation, # initial value in percents comparing to previous year
                "inflation_index": 1 + float(inflation) / 100, # convert percents to index, will be overwritten further
            })

    # recalculate index for 2019 comparing to the Jan 2019
    # currently each month value holds inflation coparing to the same month of previous year, e.g. Aug 2019 is inflation comparing to Aug 2018.
    jan2019_inflation = next(element for element in data if element["year"] == 2019 and element["month"] == 1)
    initial_jan2019_value = jan2019_inflation["inflation_index"]
    jan2019_inflation["inflation_index"] = 1 # set Jan 2019 to 1 to be a base value

    # we need to recalculate for 2019 year values comparing to Jan 2019.
    data_fixed2019 = []
    for element in data:
        if element["year"] == 2019 and element["month"] > 1:
            element["inflation_index"] = element["inflation_index"] / initial_jan2019_value
        data_fixed2019.append(element)

    # now we need to multiply indexes for each previous year to receive correct value for each month.
    # e.g. for May 2021 we need to multiply indexes for May 2019 (covers Jan 2019 - May 2019), May 2020 (covers May 2019 - May 2020) and May 2021 (covers May 2020 - 2021) to receive overall inflation from Jan 2019
    data_calculated_index = []
    for element in data_fixed2019:
        # inflation index for the same month and year lower than for current element
        inflation_for_previous_months = [element2 for element2 in data_fixed2019 if element2["month"] == element["month"] and element2["year"] <= element["year"]]
        
        data_calculated_index.append({
            "date": element["date"],
            "year": element["year"],
            "month": element["month"],
            "inflation": element["inflation"],
            "inflation_index": round(math.prod(element2["inflation_index"] for element2 in inflation_for_previous_months) * 1000) / 1000,
        })

    return data_calculated_index

cz_inflation = parse_inflation(copied_inflation_cz)
us_inflation = parse_inflation(copied_inflation_us)

# sort to be sure that all inflation records are in the same order
cz_inflation.sort(key=lambda x: x["date"])
us_inflation.sort(key=lambda x: x["date"])

result = []
for index, element in enumerate(cz_inflation):
    result.append({
        "date": element["date"],
        "year": element["year"],
        "month": element["month"],
        "cz_inflation_value": element["inflation"],
        "cz_inflation_index": element["inflation_index"],
        "us_inflation_value": us_inflation[index]["inflation"] if index < len(us_inflation) else None,
        "us_inflation_index": us_inflation[index]["inflation_index"] if index < len(us_inflation) else None,
    })

csv = ['"Date","Year","Month","CZ inflation","CZ inflation index","US inflation","US inflation index"']
csv += [",".join(map(str, element.values())) for element in result]

csv = "\n".join(csv)
print(csv)