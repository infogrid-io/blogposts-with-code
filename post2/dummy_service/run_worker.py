import logging
import time

from app import one_loop_of_model_results


logging.basicConfig()
logger = logging.getLogger()


if __name__ == "__main__":
    while True:
        try:
            one_loop_of_model_results()
            time.sleep(1)
        except Exception as e:
            logger.exception(str(e))
