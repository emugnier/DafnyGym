import csv
from difflib import ndiff
import re


def adjust_microseconds(time_str, desired_precision):
    seconds, microseconds = time_str.split(".")

    rounded_microseconds = str(round(float(f"0.{microseconds}"), desired_precision))[2:]
    padded_microseconds = rounded_microseconds.ljust(desired_precision, "0")

    adjusted_time_str = f"{seconds}.{padded_microseconds}"

    return adjusted_time_str


def read_pruning_result(csv_file_path):
    csv_data = []
    with open(csv_file_path, newline="") as csvfile:
        csv_reader = csv.DictReader(csvfile)
        for row in csv_reader:
            csv_data.append(row)
        return csv_data


def write_csv_header(csv_file_path):
    header = [
        "Index",
        "Original Method File",
        "Original Method",
        "Original Method Time",
        "Original Method Result",
        "Original Result File",
        "Assertion",
        "Time Difference",
        "New Method File",
        "New Method",
        "New Method Time",
        "New Method Result",
        "New Result File",
    ]
    csv_file = open(csv_file_path, "a", newline="")
    csv_writer = csv.writer(csv_file)
    csv_writer.writerow(header)
    return csv_writer


def write_csv_header_arg(csv_file_path, header):
    csv_file = open(csv_file_path, "w", newline="")
    csv_writer = csv.writer(csv_file)
    csv_writer.writerow(header)
    return csv_writer, csv_file


def extract_string_between_backticks(text):
    pattern = r"```(.*?)```"
    match = re.search(pattern, text, re.DOTALL)
    if match:
        return match.group(1)
    else:
        return None


def string_difference(str1, str2):
    lines1 = [line.lstrip() for line in str1.splitlines(keepends=True)]
    lines2 = [line.lstrip() for line in str2.splitlines(keepends=True)]
    diff = list(ndiff(lines1, lines2))
    diff_between_str1_str2 = "".join(s[2:] for s in diff if s[0] == "+")
    return diff_between_str1_str2
