import datetime
import logging
import os
import shutil
import subprocess

from utils.dafny_utils import (
    parse_assertion_results,
    replace_method,
    extract_dafny_functions,
    extract_error_message,
)
from utils.utils import adjust_microseconds, string_difference

logger = logging.getLogger(__name__)


class Method:
    def __init__(self, file_path, method_name, index=0, type=""):
        self.file_path = file_path
        self.moved_path = None
        self.method_name = method_name
        self.verification_time = None
        self.verification_result = None
        self.error_message = None
        self.entire_error_message = None
        self.dafny_log_file = None
        self.index = index
        self.type = ""
        if type:
            self.type = type
        self.error_message = ""
        self.error_file_path = ""

    def move_original(self, directory):
        file_name, file_extension = os.path.splitext(os.path.basename(self.file_path))
        new_file_path = os.path.join(
            directory, f"{file_name}_original.{file_extension}"
        )
        shutil.move(self.file_path, new_file_path)
        self.moved_path = new_file_path
        logger.debug(
            f"Copied method: {self.method_name} from {self.file_path} to {new_file_path}"
        )

    def move_back(self):
        file_name, file_extension = os.path.splitext(os.path.basename(self.file_path))
        if self.moved_path and os.path.exists(self.moved_path):
            shutil.move(self.moved_path, self.file_path)
            logger.debug(
                f"Move method: {self.method_name} from {self.moved_path} to {self.file_path}"
            )
        else:
            logger.debug(f"File {self.moved_path} does not exist")

    def move_to_results_directory(self, result_directory):
        if not os.path.exists(result_directory):
            os.makedirs(result_directory)

        file_name, file_extension = os.path.splitext(os.path.basename(self.file_path))
        new_file_path = os.path.join(result_directory, f"{file_name}{file_extension}")
        if os.path.exists(self.file_path):
            shutil.move(self.file_path, new_file_path)
            self.file_path = new_file_path
            return new_file_path

    # the directory needs to be where the previous file is
    # otherwise the dependencies won't work
    def create_modified_method(
        self, new_method, directory, try_nb, type="", prompt_type=""
    ):
        new_content = replace_method(
            self.get_file_content(), self.method_name, new_method
        )
        fix_filename = f"{directory}/{self.method_name}_fix_{prompt_type}_{self.index}_{try_nb}.dfy"
        with open(fix_filename, "w") as file:
            file.write(new_content)
        logger.debug(f"Created file: {fix_filename}")

        new_method = Method(fix_filename, self.method_name, index=self.index, type=type)
        return new_method

    def run_verification(self, results_directory, additionnal_args=None):
        self.dafny_log_file = f"{results_directory}/{self.method_name}_{self.index}.txt"
        if self.type:
            self.dafny_log_file = (
                f"{results_directory}/{self.method_name}_{self.type}_{self.index}.txt"
            )
        dafny_command = [
            "dafny",
            "verify",
            "--warn-deprecation:False",
            "--boogie-filter",
            f'"*{self.method_name}*"',
            "--log-format",
            f'"text;LogFileName={self.dafny_log_file}"',
            self.file_path,
        ]
        dafny_command[-1:-1] = additionnal_args.split() if additionnal_args else []
        logger.debug(dafny_command)

        try:
            result = subprocess.run(
                " ".join(dafny_command),
                check=True,
                capture_output=True,
                timeout=400,
                text=True,
                shell=True,
                executable="/usr/bin/zsh",
            )
            logger.debug(result.stdout)
        # TODO Catch timeouts
        except subprocess.CalledProcessError as e:
            if e.stderr:
                logger.error(e.stderr)
            if e.stdout:
                logger.error(e.stdout)
            self.error_message = extract_error_message(e.stdout)
            self.error_file_path = f"{results_directory}/{self.method_name}_{self.type}_{self.index}_error.txt"
            with open(self.error_file_path, "w") as file:
                file.write(e.stdout)
            self.entire_error_message = e.stdout

        self.verification_outcome = parse_assertion_results(self.dafny_log_file)
        if not self.verification_outcome:
            self.verication_result = "Syntax_Error"
            return False
        self.verification_result = (
            # self.verification_outcome[0]["overall_outcome"] == "Correct"
            self.verification_outcome[0]["overall_outcome"]
        )
        try:
            time_adjusted = adjust_microseconds(
                self.verification_outcome[0]["overall_time"], 6
            )
            time_obj = datetime.time.fromisoformat(time_adjusted)
        except ValueError as e:
            logger.error(e)
            logger.error(time_adjusted)
            self.verification_time = 0
            return False

        self.verification_time = datetime.timedelta(
            hours=time_obj.hour,
            minutes=time_obj.minute,
            seconds=time_obj.second,
            microseconds=time_obj.microsecond,
        ).total_seconds()
        return True

    def __str__(self):
        return f"Method: {self.method_name} in {self.file_path}\nVerification time: {self.verification_time} seconds\nVerification result: {self.verification_result}"

    def get_file_content(self):
        with open(self.file_path, "r") as file:
            return file.read()

    def get_method_content(self, file_content):
        return extract_dafny_functions(file_content, self.method_name)

    def get_diff(self, method_to_compare_content):
        return string_difference(
            self.get_method_content(self.get_file_content()), method_to_compare_content
        )
