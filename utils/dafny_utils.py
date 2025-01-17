import os
import re


def extract_error_message(error_string):
    pattern = re.compile(r"Error: (.+)")
    match = pattern.search(error_string)
    if match:
        return match.group(1)
    else:
        return "Error message not found in the provided string."


def extract_info_error_message(error_paragraph):
    # Extract line number
    line_number = re.search(r"\((\d+),\d+\)", error_paragraph).group(1)
    # Extract message after the file name
    message = re.search(r"\): (.+)", error_paragraph).group(1)
    # Extract code
    code = re.search(r"\| +(.+)", error_paragraph).group(1)
    return (line_number, message, code)


def compare_section_error_message(section1, section2):
    info1 = extract_info_error_message(section1)
    info2 = extract_info_error_message(section2)
    if info1[0] == info2[0] and info1[1:] == info2[1:]:
        return True
    else:
        return False


def compare_errormessage(previous_output, new_output):
    prev_sections = previous_output.split("\n\n")
    new_sections = new_output.split("\n\n")

    if len(prev_sections) != len(new_sections):
        return False

    for prev_section, new_section in zip(prev_sections, new_sections):
        if prev_section == new_section:
            continue
        if not compare_section_error_message(prev_section, new_section):
            return False

    return True


def parse_assertion_results(file_path):
    with open(file_path, "r") as f:
        data = f.read()
    assertion_batches = re.split(r"\n(?=\s*Results for \w+)", data)[1:]

    result = []
    for batch in assertion_batches:
        if not batch:
            continue
        function_match = re.search(r"Results for (\w+) \((\w+)\)", batch)
        if function_match:
            function_name = function_match.group(1)
            verification_type = function_match.group(2)
        else:
            function_name = None
            verification_type = None

        overall_outcome_match = re.search(r"Overall outcome: (\w+)", batch)
        overall_time_match = re.search(r"Overall time: (.+)", batch)
        overall_resource_count_match = re.search(
            r"Overall resource count: (\d+)", batch
        )
        max_batch_time_match = re.search(r"Maximum assertion batch time: (.+)", batch)
        max_batch_resource_count_match = re.search(
            r"Maximum assertion batch resource count: (\d+)", batch
        )
        batch_info_matches = re.finditer(
            r"Assertion batch (\d+):([\s\S]*?)(?=\n\s*Assertion batch \d+|$)", batch
        )

        batches_info = []
        for batch_info_match in batch_info_matches:
            batch_number = int(batch_info_match.group(1))
            batch_info = batch_info_match.group(2).strip()

            outcome_match = re.search(r"Outcome: (\w+)", batch_info)
            duration_match = re.search(r"Duration: (.+)", batch_info)
            resource_count_match = re.search(r"Resource count: (\d+)", batch_info)

            batch_data = {
                "batch_number": batch_number,
                "overall_outcome": outcome_match.group(1) if outcome_match else None,
                "duration": duration_match.group(1) if duration_match else None,
                "resource_count": int(resource_count_match.group(1))
                if resource_count_match
                else None,
            }

            assertions_info = []
            assertions_matches = re.finditer(
                r"(\w+\.\w+)\((\d+),(\d+)\): (.+)", batch_info
            )
            for match in assertions_matches:
                file_name, line, character, assertion_result = match.groups()

                assertions_info.append(
                    {
                        "filename": file_name,
                        "line": int(line),
                        "character": int(character),
                        "assertion_result": assertion_result,
                    }
                )

            batch_data["assertions"] = assertions_info
            batches_info.append(batch_data)

        function_data = {
            "function_name": function_name,
            "verification_type": verification_type,
            "overall_outcome": overall_outcome_match.group(1)
            if overall_outcome_match
            else None,
            "overall_time": overall_time_match.group(1) if overall_time_match else None,
            "overall_resource_count": int(overall_resource_count_match.group(1))
            if overall_resource_count_match
            else None,
            "max_batch_time": max_batch_time_match.group(1)
            if max_batch_time_match
            else None,
            "max_batch_resource_count": int(max_batch_resource_count_match.group(1))
            if max_batch_resource_count_match
            else None,
            "batches": batches_info,
        }

        result.append(function_data)

    return result


def extract_assertions(code):
    pattern = r"(\bassert\b\s+.+?;\n)"
    matches = re.findall(pattern, code)
    return matches


def replace_and_extract_method_with_line_numbers(file_path, method_string, method_name):
    # Read the file
    with open(file_path, "r") as file:
        file_content = file.read()

    # Replace the method in the file content
    new_file_content = replace_method(file_content, method_name, method_string)

    # Extract the method with line numbers
    method_with_line_numbers = extract_dafny_functions_with_line_numbers(
        new_file_content, method_name
    )

    return method_with_line_numbers


def remove_line_numbers(text):
    if not text:
        return text
    return re.sub(r"^\d+:\s", "", text, flags=re.MULTILINE)


def extract_dafny_functions_with_line_numbers(dafny_code, name):
    inside_function = False
    current_function = ""
    brace_count = 0
    line_number = 0

    lines = dafny_code.split("\n")

    for line in lines:
        line_number += 1
        if "<assertion> Insert assertion here </assertion>" in line:
            current_function += line + "\n"
            continue
        if f"lemma {name}" in line or f"method {name}" in line:
            inside_function = True
            current_function += f"{line_number}: {line}\n"
            brace_count += line.count("{") - line.count("}")
        elif inside_function:
            current_function += f"{line_number}: {line}\n"
            brace_line_count = line.count("{") - line.count("}")
            brace_count += brace_line_count

            if (
                brace_count == 0
                and "}" in line
                and (brace_line_count != 0 or "{}" in line)
            ):
                inside_function = False
                return current_function


def find_starting_line_number(file_path, method_name):
    with open(file_path, "r") as file:
        lines = file.readlines()

    for i, line in enumerate(lines, start=1):
        if line.strip().startswith(f"method {method_name}") or line.strip().startswith(
            f"lemma {method_name}"
        ):
            return i

    return None


def extract_dafny_functions(dafny_code, name):
    inside_function = False
    current_function = ""
    brace_count = 0

    lines = dafny_code.split("\n")

    for line in lines:
        if f"lemma {name}" in line or f"method {name}" in line:
            inside_function = True
            current_function += line + "\n"
            brace_count += line.count("{") - line.count("}")
        elif inside_function:
            current_function += line + "\n"
            brace_line_count = line.count("{") - line.count("}")
            brace_count += brace_line_count

            # hack to identify when a function finishes
            # {} if it is an empty function
            # otherwise expect } and with a brace count to 0 (since we are finishing the func)
            # and not an even number of braces on the line (the odd is the one to finish the func)
            if (
                brace_count == 0
                and "}" in line
                and (brace_line_count != 0 or "{}" in line)
            ):
                inside_function = False
                return current_function


def extract_method_and_lemma_names(content):
    method_names = re.findall(r"\bmethod\s+(\w+)", content)
    lemma_names = re.findall(r"\blemma\s+(\w+)", content)

    return method_names + lemma_names


def replace_method(file_content, old_method_name, new_method_content):
    function = extract_dafny_functions(file_content, old_method_name)
    print(f"function: {function}")
    dafny_code = file_content.replace(function, new_method_content)
    return dafny_code


### Both of these functions ignore files containing _fix ###
### as they are generated by our tool ###


def count_dfy_files(directory):
    return (
        sum(
            1
            for _, _, files in os.walk(directory)
            for file in files
            if file.endswith(".dfy") and "_fix" not in file
        )
        if os.path.isdir(directory)
        else 1
    )


def get_dfy_files(directory):
    if os.path.isdir(directory):
        return [
            os.path.join(root, file)
            for root, _, files in os.walk(directory)
            for file in files
            if file.endswith(".dfy") and "_fix" not in file
        ]
    else:
        return [directory]
