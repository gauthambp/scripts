import getopt
import sys


def usage():

    print("\nThis is the usage function\n")
    print('Usage: '+sys.argv[0]+'[-a|-- application_name (rlb-live-prod,d2c-live-prod,csc-stage-prod)')


def main(argv):
    try:
        fullappname, args = getopt.getopt(argv, "ho:",["org="])
        if not fullappname:
            print("No options supplied")
            usage()
    except getopt.GetoptError, e:
        print e
        usage()
        sys.exit(2)

    for opt, arg in fullappname:
        if opt in ('-a', '--'):
            usage()
            sys.exit(2)

if fullappname=="rlb-live-prod":
    import /usr/local/devops/rlb-live-prod-config
    print("source file:rlb-live-prod-config.py")

if fullappname=="rlb-stage-prod":
    import /usr/local/devops/rlb-stage-prod-config
    print("source file:rlb-stage-prod-config.py")

if fullappname=="d2c-live-prod":
    import /usr/local/devops/d2c-live-prod-config
    print("source file:d2c-live-prod-config.py")

if fullappname=="d2c-stage-prod":
    import /usr/local/devops/d2c-stage-prod-config
    print("source file:d2c-stage-prod-config.py")

if fullappname=="csc-live-prod":
    import /usr/local/devops/csc-live-prod-config
    print("source file:csc-live-prod-config.py")

if fullappname=="csc-stage-prod":
    import /usr/local/devops/csc-stage-prod-config
    print("source file:csc-stage-prod-config.py")
