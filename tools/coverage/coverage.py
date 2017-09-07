#!/usr/bin/python
# Copyright 2017 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Script to generate code coverage reports for iOS.

  NOTE: This script must be called from the root of checkout. It may take up to
        a few minutes to generate a report for targets that depend on Chrome,
        such as ios_chrome_unittests. To simply play with this tool, you are
        suggested to start with 'url_unittests'.

  ios/tools/coverage/coverage.py target
    Generate code coverage report for |target| and restrict the results to ios/.

  ios/tools/coverage/coverage.py -f path1 -f path2 target
    Generate code coverage report for |target| and restrict the results to
    |path1| and |path2|.

  For more info, please refer to ios/tools/coverage/coverage.py -h

"""

import sys

import argparse
import collections
import ConfigParser
import json
import os
import subprocess

BUILD_DIRECTORY = 'out/Coverage-iphonesimulator'
DEFAULT_GOMA_JOBS = 50

# Name of the final profdata file, and this file needs to be passed to
# "llvm-cov" command in order to call "llvm-cov show" to inspect the
# line-by-line coverage of specific files.
PROFDATA_FILE_NAME = 'coverage.profdata'

# The code coverage profraw data file is generated by running the tests with
# coverage configuration, and the path to the file is part of the log that can
# be identified with the following identifier.
PROFRAW_LOG_IDENTIFIER = 'Coverage data at '

# By default, code coverage results are restricted to 'ios/' directory.
# If the filter arguments are defined, they will override the default values.
# Having default values are important because otherwise the code coverage data
# returned by "llvm-cove" will include completely unrelated directories such as
# 'base/' and 'url/'.
DEFAULT_FILTER_PATHS = ['ios/']

# Only test targets with the following postfixes are considered to be valid.
VALID_TEST_TARGET_POSTFIXES = ['unittests', 'inttests', 'egtests']

# Used to determine if a test target is an earl grey test.
EARL_GREY_TEST_TARGET_POSTFIX = 'egtests'


def _CreateCoverageProfileDataForTarget(target, jobs_count=None):
  """Builds and runs target to generate the coverage profile data.

  Args:
    target: A string representing the name of the target to be tested.
    jobs_count: Number of jobs to run in parallel for building. If None, a
                default value is derived based on CPUs availability.

  Returns:
    A string representing the absolute path to the generated profdata file.
  """
  _BuildTargetWithCoverageConfiguration(target, jobs_count)
  profraw_path = _GetProfileRawDataPathByRunningTarget(target)
  profdata_path = _CreateCoverageProfileDataFromProfRawData(profraw_path)

  print 'Code coverage profile data is created as: ' + profdata_path
  return profdata_path


def _DisplayLineCoverageReport(target, profdata_path, filter_paths):
  """Generates and displays line coverage report.

  The output has the following format:
  Line Coverage Report for the Following Directories:
  dir1:
    Total Lines: 10 Executed Lines: 5 Missed Lines: 5  Coverage: 50%
  dir2:
    Total Lines: 20 Executed Lines: 2 Missed lines: 18 Coverage: 10%
  In Aggregate:
    Total Lines: 30 Executed Lines: 7 Missed Lines: 23 Coverage: 23%

  Args:
    target: A string representing the name of the target to be tested.
    profdata_path: A string representing the path to the profdata file.
    filter_paths: A list of directories used to restrict code coverage results.
  """
  print 'Generating code coverge report'
  coverage_json = _ExportCodeCoverageToJson(target, profdata_path)
  raw_line_coverage_report = _GenerateLineCoverageReport(coverage_json)
  line_coverage_report = _FilterLineCoverageReport(raw_line_coverage_report,
                                                   filter_paths)

  coverage_by_filter = collections.defaultdict(
      lambda: collections.defaultdict(lambda: 0))
  for coverage_file in line_coverage_report:
    file_name = coverage_file['filename']
    total_lines = coverage_file['summary']['count']
    executed_lines = coverage_file['summary']['covered']

    matched_filter_paths = _MatchFilePathWithDirectories(file_name,
                                                         filter_paths)
    for matched_filter in matched_filter_paths:
      coverage_by_filter[matched_filter]['total_lines'] += total_lines
      coverage_by_filter[matched_filter]['executed_lines'] += executed_lines

    if matched_filter_paths:
      coverage_by_filter['aggregate']['total_lines'] += total_lines
      coverage_by_filter['aggregate']['executed_lines'] += executed_lines

  print '\nLine Coverage Report for Following Directories: ' + str(filter_paths)
  for filter_path in filter_paths:
    print filter_path + ':'
    _PrintLineCoverageStats(coverage_by_filter[filter_path]['total_lines'],
                            coverage_by_filter[filter_path]['executed_lines'])

  if len(filter_paths) > 1:
    print 'In Aggregate:'
    _PrintLineCoverageStats(coverage_by_filter['aggregate']['total_lines'],
                            coverage_by_filter['aggregate']['executed_lines'])


def _ExportCodeCoverageToJson(target, profdata_path):
  """Exports code coverage data.

  Args:
    target: A string representing the name of the target to be tested.
    profdata_path: A string representing the path to the profdata file.

  Returns:
    A json object whose format can be found at:
    https://github.com/llvm-mirror/llvm/blob/master/tools/llvm-cov/CoverageExporterJson.cpp.
  """
  application_path = _GetApplicationBundlePath(target)
  binary_path = os.path.join(application_path, target)
  cmd = ['xcrun', 'llvm-cov', 'export', '-instr-profile', profdata_path,
         '-arch=x86_64', binary_path]
  std_out = subprocess.check_output(cmd)
  return json.loads(std_out)


def _GenerateLineCoverageReport(coverage_json):
  """Generates a line coverage report out of exported coverage json data.

  Args:
    coverage_json: A json object whose format can be found at:
        https://github.com/llvm-mirror/llvm/blob/master/tools/llvm-cov/CoverageExporterJson.cpp.

  Returns:
    A json object with the following format:

    Root: array => List of objects describing line covearge summary for files
    -- File: dict => Line coverage summary for a single file
    ---- FileName: str => Name of tis file
    ---- Summary: dict => Object summarizing the line coverage for this file
  """
  assert len(coverage_json['data']) == 1, ('There should be only one export '
                                           'object for a single target.')
  coverage_data = coverage_json['data'][0]
  coverage_files = coverage_data['files']

  coverage_lines_report = []
  for coverage_file in coverage_files:
    summary_lines = coverage_file['summary']['lines']
    coverage_lines_file = {
        'filename': coverage_file['filename'],
        'summary': summary_lines
    }
    coverage_lines_report.append(coverage_lines_file)

  return coverage_lines_report


def _FilterLineCoverageReport(raw_report, filter_paths):
  """Filter line coverage report to only include directories in |filter_paths|.

  Args:
    raw_report: A json object with the following format:
      Root: array => List of objects describing line covearge summary for files
      -- File: dict => Line coverage summary for a single file
      ---- FileName: str => Name of this file
      ---- Summary: dict => Object summarizing the line coverage for this file
    filter_paths: A list of directories used to restrict code coverage results.

  Returns:
    A json object with the following format:

    Root: array => List of objects describing line covearge summary for files
    -- File: dict => Line coverage summary for a single file
    ---- FileName: str => Name of this file
    ---- Summary: dict => Object summarizing the line coverage for this file
  """
  filtered_report = []
  for coverage_lines_file in raw_report:
    file_name = coverage_lines_file['filename']
    if _MatchFilePathWithDirectories(file_name, filter_paths):
      filtered_report.append(coverage_lines_file)

  return filtered_report


def _PrintLineCoverageStats(total_lines, executed_lines):
  """Print line coverage statistics.

  The format is as following:
    Total Lines: 20 Executed Lines: 2 missed lines: 18 Coverage: 10%

  Args:
    total_lines: number of lines in total.
    executed_lines: number of lines that are executed.
  """
  missed_lines = total_lines - executed_lines
  coverage = float(executed_lines) / total_lines if total_lines > 0 else None
  percentage_coverage = '{}%'.format(int(coverage * 100)) if coverage else None

  output = ('\tTotal Lines: {}\tExecuted Lines: {}\tMissed Lines: {}\t'
            'Coverage: {}\n')
  print output.format(total_lines, executed_lines, missed_lines,
                      percentage_coverage or 'NA')


def _MatchFilePathWithDirectories(file_path, directories):
  """Returns the directories that contains the file.

  Args:
    file_path: the absolute path of a file that is to be matched.
    directories: A list of directories that are relative to source root.

  Returns:
    A list of directories that contains the file.
  """
  matched_directories = []
  src_root = _GetSrcRootPath()
  relative_file_path = os.path.relpath(file_path, src_root)
  for directory in directories:
    if relative_file_path.startswith(directory):
      matched_directories.append(directory)

  return matched_directories


def _BuildTargetWithCoverageConfiguration(target, jobs_count):
  """Builds target with coverage configuration.

  This function requires current working directory to be the root of checkout.

  Args:
    target: A string representing the name of the target to be tested.
    jobs_count: Number of jobs to run in parallel for compilation. If None, a
                default value is derived based on CPUs availability.
  """
  print 'Building ' + target

  src_root = _GetSrcRootPath()
  build_dir_path = os.path.join(src_root, BUILD_DIRECTORY)

  cmd = ['ninja', '-C', build_dir_path]
  if jobs_count:
    cmd.append('-j' + str(jobs_count))

  cmd.append(target)
  subprocess.check_call(cmd)


def _GetProfileRawDataPathByRunningTarget(target):
  """Runs target and returns the path to the generated profraw data file.

  The output log of running the test target has no format, but it is guaranteed
  to have a single line containing the path to the generated profraw data file.

  Args:
    target: A string representing the name of the target to be tested.

  Returns:
    A string representing the absolute path to the generated profraw data file.
  """
  logs = _RunTestTargetWithCoverageConfiguration(target)
  for log in logs:
    if PROFRAW_LOG_IDENTIFIER in log:
      profraw_path = log.split(PROFRAW_LOG_IDENTIFIER)[1][:-1]
      return os.path.abspath(profraw_path)

  assert False, ('No profraw data file is generated, did you call '
                 'coverage_util::ConfigureCoverageReportPath() in test setup? '
                 'Please refer to base/test/test_support_ios.mm for example.')


def _RunTestTargetWithCoverageConfiguration(target):
  """Runs tests to generate the profraw data file.

  This function requires current working directory to be the root of checkout.

  Args:
    target: A string representing the name of the target to be tested.

  Returns:
    A list of lines/strings created from the output log by breaking lines. The
    log has no format, but it is guaranteed to have a single line containing the
    path to the generated profraw data file.
  """
  print 'Running ' + target

  iossim_path = _GetIOSSimPath()
  application_path = _GetApplicationBundlePath(target)

  cmd = [iossim_path, application_path]
  if _TargetIsEarlGreyTest(target):
    cmd.append(_GetXCTestBundlePath(target))

  logs_chracters = subprocess.check_output(cmd)
  return ''.join(logs_chracters).split('\n')


def _CreateCoverageProfileDataFromProfRawData(profraw_path):
  """Returns the path to the profdata file by merging profraw data file.

  Args:
    profraw_path: A string representing the absolute path to the profraw data
                  file that is to be merged.

  Returns:
    A string representing the absolute path to the generated profdata file.

  Raises:
    CalledProcessError: An error occurred merging profraw data files.
  """
  print 'Creating the profile data file'

  src_root = _GetSrcRootPath()
  profdata_path = os.path.join(src_root, BUILD_DIRECTORY,
                               PROFDATA_FILE_NAME)
  try:
    cmd = ['xcrun', 'llvm-profdata', 'merge', '-o', profdata_path, profraw_path]
    subprocess.check_call(cmd)
  except subprocess.CalledProcessError as error:
    print 'Failed to merge profraw to create profdata.'
    raise error

  return profdata_path


def _GetSrcRootPath():
  """Returns the absolute path to the root of checkout.

  Returns:
    A string representing the absolute path to the root of checkout.
  """
  return os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir,
                                      os.pardir, os.pardir))


def _GetApplicationBundlePath(target):
  """Returns the path to the generated application bundle after building.

  Args:
    target: A string representing the name of the target to be tested.

  Returns:
    A string representing the path to the generated application bundle.
  """
  src_root = _GetSrcRootPath()
  application_bundle_name = target + '.app'
  return os.path.join(src_root, BUILD_DIRECTORY, application_bundle_name)


def _GetXCTestBundlePath(target):
  """Returns the path to the xctest bundle after building.

  Args:
    target: A string representing the name of the target to be tested.

  Returns:
    A string representing the path to the generated xctest bundle.
  """
  application_path = _GetApplicationBundlePath(target)
  xctest_bundle_name = target + '_module.xctest'
  return os.path.join(application_path, 'PlugIns', xctest_bundle_name)


def _GetIOSSimPath():
  """Returns the path to the iossim executable file after building.

  Returns:
    A string representing the path to the iossim executable file.
  """
  src_root = _GetSrcRootPath()
  iossim_path = os.path.join(src_root, BUILD_DIRECTORY, 'iossim')
  return iossim_path


def _IsGomaConfigured():
  """Returns True if goma is enabled in the gn build settings.

  Returns:
    A boolean indicates whether goma is configured for building or not.
  """
  # Load configuration.
  settings = ConfigParser.SafeConfigParser()
  settings.read(os.path.expanduser('~/.setup-gn'))
  return settings.getboolean('goma', 'enabled')


def _TargetIsEarlGreyTest(target):
  """Returns true if the target is an earl grey test.

  Args:
    target: A string representing the name of the target to be tested.

  Returns:
    A boolean indicates whether the target is an earl grey test or not.
  """
  return target.endswith(EARL_GREY_TEST_TARGET_POSTFIX)


def _TargetNameIsValidTestTarget(target):
  """Returns True if the target name has a valid postfix.

  The list of valid target name postfixes are defined in
  VALID_TEST_TARGET_POSTFIXES.

  Args:
    target: A string representing the name of the target to be tested.

  Returns:
    A boolean indicates whether the target is a valid test target.
  """
  return (any(target.endswith(postfix) for postfix in
              VALID_TEST_TARGET_POSTFIXES))


def _ParseCommandArguments():
  """Add and parse relevant arguments for tool commands.

  Returns:
    A dictionanry representing the arguments.
  """
  arg_parser = argparse.ArgumentParser()
  arg_parser.usage = __doc__

  arg_parser.add_argument('-f', '--filter', type=str, action='append',
                          help='Paths used to restrict code coverage results '
                               'to specific directories, and the default value '
                               'is \'ios/\'. \n'
                               'NOTE: if this value is defined, it will '
                               'override instead of appeding to the defaults.')

  arg_parser.add_argument('-j', '--jobs', type=int, default=None,
                          help='Run N jobs to build in parallel. If not '
                               'specified, a default value will be derived '
                               'based on CPUs availability. Please refer to '
                               '\'ninja -h\' for more details.')

  arg_parser.add_argument('target', nargs='+',
                          help='The name of the test target to run.')

  args = arg_parser.parse_args()
  return args


def _AssertCoverageBuildDirectoryExists():
  """Asserts that the build directory with converage configuration exists."""
  src_root = _GetSrcRootPath()
  build_dir_path = os.path.join(src_root, BUILD_DIRECTORY)
  assert os.path.exists(build_dir_path), (build_dir_path + " doesn't exist."
                                          'Hint: run gclient runhooks or '
                                          'ios/build/tools/setup-gn.py.')


def _AssertFilterPathsExist(filter_paths):
  """Asserts that paths specified in |filter_paths| exist.

  Args:
    filter_paths: A list of directories.
  """
  src_root = _GetSrcRootPath()
  for filter_path in filter_paths:
    filter_abspath = os.path.join(src_root, filter_path)
    assert os.path.exists(filter_abspath), ('Filter path: {} doesn\'t exist.\n '
                                            'A valid filter path must exist '
                                            'and be relative to the root of '
                                            'source, which is {} \nFor '
                                            'example, \'ios/\' is a valid '
                                            'filter.').format(filter_abspath,
                                                              src_root)


def Main():
  """Executes tool commands."""
  args = _ParseCommandArguments()
  targets = args.target
  assert len(targets) == 1, ('targets: ' + str(targets) + ' are detected, '
                             'however, only a single target is supported now.')

  target = targets[0]
  if not _TargetNameIsValidTestTarget(target):
    assert False, ('target: ' + str(target) + ' is detected, however, only '
                   'target name with the following postfixes are supported: ' +
                   str(VALID_TEST_TARGET_POSTFIXES))

  jobs = args.jobs
  if not jobs and _IsGomaConfigured():
    jobs = DEFAULT_GOMA_JOBS

  _AssertCoverageBuildDirectoryExists()
  _AssertFilterPathsExist(args.filter)

  profdata_path = _CreateCoverageProfileDataForTarget(target, jobs)
  _DisplayLineCoverageReport(target, profdata_path,
                             args.filter or DEFAULT_FILTER_PATHS)

if __name__ == '__main__':
  sys.exit(Main())
