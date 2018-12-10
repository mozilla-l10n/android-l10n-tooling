from setuptools import setup, find_packages

setup(
    name="mozxchannel",
    version="0.1",
    packages=find_packages(
        exclude=["tests"],
    ),
    tests_require=[
        "cram",
    ]
)
