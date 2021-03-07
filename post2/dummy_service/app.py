import random
import json
import logging
import time

import requests

from settings import MODEL_NAME, TENSORFLOW_DNS, TENSORFLOW_PORT, LOG_LEVEL

level = logging.getLevelName(LOG_LEVEL)
logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(level)


def random_data_generator(length):
    """Generate random data to send to the model."""
    random_list = [[[random.random()] for x in range(length)]]
    return random_list


def send_data_to_model(tensorflow_dns, tensorflow_port, model_name, data_array):
    """Use Tensorflow Serving REST API to send data to the model and receive the output."""
    start = time.time()
    logger.debug(f"Starting request to model with data {data_array}")
    response = requests.post(
        url=f"http://{tensorflow_dns}:{tensorflow_port}/v1/models/{model_name}:predict",
        data=json.dumps({"signature_name": "serving_default", "inputs": data_array}),
        headers={"content-type": "application/json"},
        timeout=10,
    )
    end = time.time()
    response_status_code = response.status_code
    logger.debug(f"status code is {response_status_code}")
    logger.debug(f"REST processing time is {float(end - start)} seconds")
    output = json.loads(response.text)
    probability = output["outputs"][0][0]
    return probability


def one_loop_of_model_results():
    """Wrapper to run the model based on the generated data and output the result."""
    data_array = random_data_generator(length=2)
    probability = send_data_to_model(
        TENSORFLOW_DNS, TENSORFLOW_PORT, MODEL_NAME, data_array
    )
    logger.info(f"model outcome for {data_array} is {probability}")
    return None
