"""Verify linear sorted-catalog admission and duplicate/error precedence."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('host_catalog_verifier', ROOT / 'tools/verify-host-catalog.py')
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)
host.suite.DESCRIPTION = __doc__
host.suite.DIRECTORY = 'build/host-catalog-order'
host.suite.EXTRA_INPUTS.add('tools/verify-host-catalog-order.py')
host.suite.MODULES = {'host_catalog': None, 'host_catalog_order': None}
if __name__ == '__main__':
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    host.verify_reference()
    host.suite.main()
