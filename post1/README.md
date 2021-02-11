# How to deploy Tensorflow with a Serverless Architecture on AWS with Terraform (Part 1)
### 11th February 2021
### Aidan Russell


At Infogrid we utilise models implemented in Tensorflow for a number of data science use-cases, and among its benefits is its lightweight Tensorflow Serving package. I aim to lay out some clear steps for those looking to move from making interesting experimental models in Tensorflow (for which there are many examples out there) to actually deploying them to production (for which there are very few clearly laid out examples to be found).

The main Tensorflow package is several hundred megabytes, including modules related to training that are unnecessary for predictions. You do not want this library to be part of the rest of your production service - rather the best approach is to split your architecture into one service that receives data and prepares it to be sent to the model, and a second which hosts only the model and the Tensorflow Serving environment. Pre-prepared Docker containers loaded with Tensorflow Serving (i.e. no modules related to training) are readily available (see [here](https://hub.docker.com/r/tensorflow/serving)). One can then connect the two services via one of two options: [REST](https://en.wikipedia.org/wiki/Representational_state_transfer) or [gRPC](https://en.wikipedia.org/wiki/GRPC). Since REST is generally more straightforward to implement (though less performant), I will describe the process for that approach. The trained model itself is stored within a file system such as s3, and it is straightforward to set it up in such a way that the Serving container will periodically check the s3 bucket to see if a new model has been uploaded - if it has, it can redeploy automatically with the new model (this is just one of the many handy features that make Tensorflow Serving such a delight to work with).

In order to first clarify how the Serving environment operates, it is instructive to download one of the Serving Docker containers as listed above and load a model. I have stored a dummy test model and all associated code required in [this github repository](https://github.com/aidanrussell/blogpost_code/tree/master/post1)

```
docker pull tensorflow/serving:2.4.0
docker run -p 8500:8500 -p 8501:8501 -v ${LOCAL_PATH_TO_MODEL}:/models/empty_model -e MODEL_NAME=empty_model tensorflow/serving:2.4.0
```

And now you can send data to the model and receive back its prediction with the following:

```
import requests
import json

data_input = [[[0.3], [0.2]]]

headers = {"content-type": "application/json"}
SERVER_URL = "http://localhost:8501/v1/models/empty_model:predict"
body = {
    "signature_name": "serving_default",
    "inputs" : data_input,
}
response = requests.post(SERVER_URL, data=json.dumps(body), headers = headers)
output = json.loads(response.text)
probability = output['outputs'][0][0]
outcome = int(probability > 0.5)
print(f"outcome: {outcome}", f"\nprobability: {probability}")
```

Note the format of data_input requires additional nesting lists compared to what you might expect - hence why this kind of local testing is important to clarify how you should transform the data in production. You can of course replace the "empty_model" that has been stored in the associated code repository with another of your own.

We can use Terraform to set this up in Amazon Web Services (AWS). Hopefully even if you use a different cloud provider, these templates will still be helpful. To avoid the complication of setting up our second service that would actually interact with this model in a production system, we will instead deploy the Serving container as a solo service within a Virtual Private Cloud (VPC) and assign an Application Load Balancer (ALB) which will be internet-facing and to which we can send our requests from a local machine. In a production system, we would instead be deploying a second service also within the VPC and our ALB would not face the internet in that case (all of this is configurable within the Terraform code).

We can walk through the Terraform code (see the [github repository](?)), and note that Hashicorp actually provides very good [documentation for Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) which you can reference also. In order to aid understand I have split the functionality roughly into four `.tf` files - `network.tf`, `outputs.tf`, `security.tf`, and `tensorflow.tf` (these could all have been one file as far as Terraform itself is concerned).

### network.tf
Within `network.tf` you can see that we describe the VPC and its associated properties, including subnets and an internet gateway to allow an outside access point.

### outputs.tf
Within `outputs.tf` we place the Domain Name System (DNS) reference for the application load balancer, which is where we will send requests to from our local machine (this reference is auto-generated by AWS upon creation of the ALB).

## security.tf
Within `security.tf` we describe our AWS security group, including which ports are to be opened (Tensorflow Serving receives and sends data on port 8500 for gRPC and 8501 for REST, and we have designated our ALB to send and receive on port 9000 and forward that to port 8501 for Serving).

### tensorflow.tf
In `tensorflow.tf` we define the container for Serving, including the image reference (the same public repository we used when running on our local machine earlier) and a number of environment variables used to reference the model stored in s3 - in fact placing the model in s3 is the only additional step not covered here, because within `tensorflow.tf` we have defined the creation of this s3 bucket (and note you will have to use a different name to the one I have chosen because bucket names must be globally unique) but it is left up to the user to actually place their model into this bucket in order to be found by their tensorflow service. Serving will query the bucket every 10 minutes to see if there have been any updates, so this must be done after `terraform apply` has been called and the s3 bucket created.

Hence the steps to deploy in AWS:
- Download the repository stored in [this github link](?)
- Navigate to the `terraform/` folder
- Review the `variables.auto.tfvars` file and make any alterations - change the s3 bucket name to something globally unique; if you wish to use your own model rather than the one provided within the repository then you would also need to change the model_name correspondingly
- Send the tensorflow/serving:2.4.0 image you downloaded previously up to your own Elastic Container Registry (see appendix)
- `terraform init`
- `terraform plan` and review to check you follow the steps
- `terraform apply`
- Upload the model to the s3 bucket; note that since Tensorflow saves models in a format consisting of a folder with several constituent files, you must make sure you upload the whole folder without compression
- Once the apply has completed the `tensorflow_lb_dns` should be output to your terminal screen; copy it down
- Since we have used DEBUG log level, you can review that the model has been loaded in the AWS Console by navigating to Cloudwatch and searching for the logs group referenced in `variables.auto.tfvars`
- If you navigate in the AWS Console to the EC2 Target Groups section, you can inspect the health check we placed on our tensorflow service

Now, on your local machine you can make requests to the deployed model with:

```
import requests
import json

data_input = [[[0.3], [0.2]]]

headers = {"content-type": "application/json"}
tensorflow_lb_dns = ${output of terraform apply performed above}$
SERVER_URL = f"http://{tensorflow_lb_dns}:8888/v1/models/empty_model:predict"
body = {
    "signature_name": "serving_default",
    "inputs" : data_input,
}
response = requests.post(SERVER_URL, data=json.dumps(body), headers = headers)
output = json.loads(response.text)
probability = output['outputs'][0][0]
outcome = int(probability > 0.5)
print(f"outcome: {outcome}", f"\nprobability: {probability}")
```

Happy Terraforming!



Appendix: Sending a docker image held locally to ECR:
- run `docker image ls` and identify the container tensorflow/serving:2.4.0 and note its image id
- take note of your AWS account id, and a suitable container repository in ECR 
- tag the image with `docker tag ${image id}$ ${AWS account id}$.dkr.ecr.${region}$.amazonaws.com/${container registry}$:${any arbitrary additional naming convention}$`
- run `aws ecr get-login-password --region ${region}$ | docker login --username AWS --password-stdin "${AWS account id}$.dkr.ecr.${region}$.amazonaws.com"`
- run `docker push ${AWS account id}$.dkr.ecr.${region}$.amazonaws.com/${container registry}$:${any arbitrary additional naming convention}$`
- replace the tensorflow_image variable in the `variables.auto.tfvars` file with the same path