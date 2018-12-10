from glob import glob
import os
import sys
from cram import main


DIR = os.path.dirname(__file__)
os.environ['PYTHON'] = sys.executable


class CramMeta(type):
    def __new__(cls, clsname, superclasses, attributedict):
        fls = glob(os.path.join(DIR, attributedict['test_filter']))
        for f in fls:
            f = os.path.relpath(f, DIR)
            tn = os.path.basename(f)
            tn = os.path.splitext(tn)[0]
            tn = tn.replace('-', '_')

            def create_test(test_name, function_name):
                def test_(self):
                    self.assertFalse(main([os.path.join(DIR, test_name)]))
                test_.__name__ = function_name
                return test_
            attributedict[tn] = create_test(f, tn)
        return super().__new__(cls, clsname, superclasses, attributedict)
