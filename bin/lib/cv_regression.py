################################################################################
#
# Copyright 2020 OpenHW Group
# 
# Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://solderpad.org/licenses/
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier:Apache-2.0 WITH SHL-2.0
# 
################################################################################

import os
import sys
import logging
from collections import OrderedDict

logger = logging.getLogger(__name__)

DEFAULT_ISS = 'YES'
DEFAULT_SIMULATION_PASSED = 'SIMULATION PASSED'
DEFAULT_SKIP_SIM = []

class Build:
    '''A regression build object'''
    def __init__(self, **kwargs):

        # Create defaults    
        self.iss = DEFAULT_ISS

        for k, v in kwargs.items():            
            setattr(self, k, v)

    def __str__(self):
        return '{} {} {}'.format(self.name, self.cmd, self.dir)

class Test:
    '''A regression test object'''
    def __init__(self, **kwargs):
        '''Create a test object'''

        # Set defaults
        self.skip_sim = DEFAULT_SKIP_SIM
        self.simulation_passed = DEFAULT_SIMULATION_PASSED
        self.iss = DEFAULT_ISS
        self.num = 1

        for k, v in kwargs.items():
            setattr(self, k, v)

class Regression:
    '''A full regression object'''
    def __init__(self, **kwargs):
        '''Constructor'''
        self.builds = OrderedDict()
        self.tests = OrderedDict()

        for k, v in kwargs.items():
            setattr(self, k, v)

    def add_build(self, build):
        '''Add a new build object to this regression'''
        if build.name in self.builds.keys():
            logger.fatal('Build: {} was defined multiple times'.format(build['name']))
            os.sys.exit(2)

        self.builds[build.name] = build
    
    def add_test(self, test):
        '''Add a new test object to this regression'''
        if test.name in self.tests.keys():
            logger.fatal('Test: {} was defined multiple times'.format(test['name']))
            os.sys.exit(2)

        self.tests[test.name]  = test
    