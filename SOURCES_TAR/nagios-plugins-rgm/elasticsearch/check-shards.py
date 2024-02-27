import requests
import sys
import json
import argparse
import os


class ElasticsearchClusterChecker:
    def __init__(self, url, user, password, max_shards, warning, critical, debug=False):
        self.url = url
        self.user = user
        self.password = password
        self.max_shards = max_shards
        self.warning = warning
        self.critical = critical
        self.debug = debug

    def _make_request(self):
        try:
            response = requests.get("{}/_cluster/health".format(self.url), auth=(self.user, self.password))
            if response.status_code == 401 or response.status_code == 403:
                print("CRITICAL - Elasticsearch cluster authentication failed (HTTP {})".format(response.status_code))
                sys.exit(2)
            elif response.status_code != 200:
                print("UNKNOWN - Unexpected response from Elasticsearch cluster (HTTP {})".format(response.status_code))
                sys.exit(3)
            return response.json()
        except Exception as e:
            print("UNKNOWN - Error while checking Elasticsearch cluster: {}".format(e))
            sys.exit(3)

    def check_cluster_state(self):
        response_json = self._make_request()

        # Check the cluster state
        cluster_state = response_json.get("status")
        active_shards = response_json.get("active_shards")

        message = ""
        output_data = ""
        exit_code = 0
        if cluster_state == "green":
            message = "OK - Elasticsearch cluster is healthy"
        elif cluster_state == "yellow":
            message = "WARNING - Elasticsearch cluster state is yellow"
            exit_code = 1
        else:
            message = "CRITICAL - Elasticsearch cluster state is red"
            exit_code = 2

        # Check the number of active shards
        if active_shards is not None:
            # print(f"Number of active shards: {active_shards}")
            # Check if the number of active shards exceeds the limit
            warning_level = int(self.max_shards * self.warning / 100)
            critical_level = int(self.max_shards * self.critical / 100)
            output_data = "|value={};{};{};0;{}".format(active_shards, warning_level, critical_level, self.max_shards)
            if active_shards >= critical_level:
                message = "CRITICAL - Number of active shards exceeds the limit ({}/{})".format(active_shards, self.max_shards)
                exit_code = 2
            elif active_shards >= warning_level:
                message = "WARNING - Number of active shards exceeds the limit ({}/{})".format(active_shards, self.max_shards)
                exit_code = 1
        else:
            message = "UNKNOWN - Unable to retrieve the number of active shards"
            exit_code = 3

        # Display the complete JSON response for debugging
        if self.debug:
            print("Complete JSON response:")
            print(json.dumps(response_json, indent=2))

        print(message + output_data)
        sys.exit(exit_code)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check Elasticsearch cluster state")
    parser.add_argument("--url", default=os.environ.get("ELASTICSEARCH_URL", "http://your-elasticsearch-cluster:9200"),
                        help="Elasticsearch cluster URL")
    parser.add_argument("--user", default=os.environ.get("ELASTICSEARCH_USER", "your-username"),
                        help="Username for authentication")
    parser.add_argument("--password", default=os.environ.get("ELASTICSEARCH_PASSWORD", "your-password"),
                        help="Password for authentication")
    parser.add_argument("--max-shards", type=int, default=int(os.environ.get("MAX_ACTIVE_SHARDS", 3000)),
                        help="Maximum active shards limit")
    parser.add_argument("--warning", type=int, default=80,
                        help="Warning percentage")
    parser.add_argument("--critical", type=int, default=90,
                        help="Critical percentage")
    parser.add_argument("--debug", action="store_true", help="Enable debug mode to display complete JSON response")
    args = parser.parse_args()

    checker = ElasticsearchClusterChecker(args.url, args.user, args.password, args.max_shards, args.warning, args.critical, args.debug)
    checker.check_cluster_state()
