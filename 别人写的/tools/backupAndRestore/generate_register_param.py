import logging
import sys

logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s %(filename)s[line:%(lineno)d] '
                           '%(levelname)s %(message)s',
                    datefmt='%Y-%m-%d %H:%M:%S',
                    filename='/var/log/ha/shelllog/generate_register_param.log',
                    filemode='a')


def generate_register_param(sub_system, mode, path, md5ServerParam):
    logging.debug("start to generate.")

    function_list = []
    param = {"function": function_list}
    instance = {"subSystem": sub_system, "services": [], "isDecoup":
                "false", "type": "2", "state": mode, "serverCheckCode": md5ServerParam
                }
    body = {"subSystem": sub_system, "feature": "back_res",
            "call_path": path, "call_period": 60,
            "param": param, "instance": instance
            }
    logging.info("Successfully to generate register param.")
    return body

if __name__ == "__main__":
    if sys.argv[1] and sys.argv[2] and sys.argv[3]:
        sub_system = sys.argv[1]
        mode = sys.argv[2]
        path = sys.argv[3]
        md5ServerParam = sys.argv[4]
        print generate_register_param(sub_system, mode, path, md5ServerParam)

    else:
        logging.error("Please check the input.")
