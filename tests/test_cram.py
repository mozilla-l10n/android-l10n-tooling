from unittest import TestCase
from . import CramMeta



class TestCram(TestCase, metaclass=CramMeta):
    test_filter = 'test-*.t'
