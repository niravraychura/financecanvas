import unittest
from scripts.fingerprint import transaction_fingerprint

class FingerprintTests(unittest.TestCase):
    def test_same_record_is_stable(self):
        record={"workspace_id":"workspace-demo","account_id":"account-demo","posted_date":"2026-09-30","amount":"1250.00","currency":"INR","direction":"debit","reference":"ABC123","raw_description":"DEMO MERCHANT"}
        self.assertEqual(transaction_fingerprint(record),transaction_fingerprint(dict(record)))

    def test_material_change_changes_fingerprint(self):
        base={"workspace_id":"workspace-demo","account_id":"account-demo","posted_date":"2026-09-30","amount":"1250.00","currency":"INR","direction":"debit","reference":"ABC123","raw_description":"DEMO MERCHANT"}
        self.assertNotEqual(transaction_fingerprint(base),transaction_fingerprint(dict(base,amount="1251.00")))

if __name__=="__main__":
    unittest.main()
