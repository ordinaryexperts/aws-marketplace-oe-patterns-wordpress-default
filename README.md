# aws-marketplace-oe-patterns-wordpress-default

## Upgrading

To upgrade WordPress / Bedrock, do the following:

```
$ git flow feature start upgrade
$ rm -rf bedrock
$ composer create-project roots/bedrock bedrock
$ git add .
$ git commit -m "upgrading bedrock/wordpress to version x.x.x"
$ git push
```

This will trigger a GitHub action which will upload a zip of the default site to s3.

Then you can update the `DEFAULT_WORDPRESS_SOURCE_URL` in the `wordpress_stack.py` file in the CDK project to match.

Also, you need to delete the existing source file in S3 for the initialization code to be re-triggered.
