##########################################################################
#
# pgAdmin 4 - PostgreSQL Tools
#
# Copyright (C) 2013 - 2025, The pgAdmin Development Team
# This software is released under the PostgreSQL Licence
#
##########################################################################


import json

from pgadmin.browser.server_groups.servers.databases.tests import \
    utils as database_utils
from pgadmin.utils.route import BaseTestGenerator
from regression import parent_node_dict
from regression.python_test_utils import test_utils as utils
from . import utils as extension_utils


class ExtensionsPutTestCase(BaseTestGenerator):
    scenarios = [
        # Fetching default URL for extension node.
        ('Check Extension Node', dict(url='/browser/extension/obj/'))
    ]

    def setUp(self):
        """ This function will create extension."""
        super().setUp()
        self.schema_data = parent_node_dict['schema'][-1]
        self.server_id = self.schema_data['server_id']
        self.db_id = self.schema_data['db_id']
        self.schema_name = self.schema_data['schema_name']
        self.extension_name = "cube"
        self.db_name = parent_node_dict["database"][-1]["db_name"]
        self.extension_id = extension_utils.create_extension(
            self.server, self.db_name, self.extension_name, self.schema_name)

    def runTest(self):
        """ This function will update extension added under test database. """
        db_con = database_utils.connect_database(self,
                                                 utils.SERVER_GROUP,
                                                 self.server_id,
                                                 self.db_id)
        if not db_con["info"] == "Database connected.":
            raise Exception("Could not connect to database.")
        response = extension_utils.verify_extension(self.server, self.db_name,
                                                    self.extension_name)
        if not response:
            raise Exception("Could not find extension.")
        data = {
            "schema": "public",
            "id": self.extension_id
        }
        put_response = self.tester.put(
            self.url + str(utils.SERVER_GROUP) + '/' +
            str(self.server_id) + '/' + str(
                self.db_id) +
            '/' + str(self.extension_id),
            data=json.dumps(data),
            follow_redirects=True)
        self.assertEqual(put_response.status_code, 200)

    def tearDown(self):
        """This function disconnect the test database and drop added
        extension."""
        extension_utils.drop_extension(self.server, self.db_name,
                                       self.extension_name)
        database_utils.disconnect_database(self, self.server_id, self.db_id)
