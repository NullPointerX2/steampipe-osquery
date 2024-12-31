"""
This script can be used to download the latest Osquery table schema information that the Steampipe plugin requires to display all available information about the tables.
This data can be found here (replace X.X.X.json by the current version): https://raw.githubusercontent.com/osquery/osquery-site/source/src/data/osquery_schema_versions/X.X.X.json
"""

import requests
import json

def download_and_parse_json(url):
    response = requests.get(url)
    response.raise_for_status() 

    data = response.json()

    # these are columns needed by the plugin
    filtered_data = [
        {
            "name": table["name"],
            "description": table["description"],
            "examples": table["examples"],
            "columns": [
                {
                    "name": column["name"],
                    "description": column["description"]
                }
                for column in table["columns"]
            ]
        } 
        for table in data
    ]

    return filtered_data

def main():
    url = input("Enter the URL of the current osquery table schema json: ")

    filtered_data = download_and_parse_json(url)

    with open("osquery/osquery_schemas.json", "w") as outfile:
        json.dump(filtered_data, outfile, indent=4)

    print("Filtered data has been saved to 'osquery_schemas.json'.")

if __name__ == "__main__":
    main()
