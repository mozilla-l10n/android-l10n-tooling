from setuptools import setup, find_packages

setup(
    name="mozxchannel",
    version="0.1",
    entry_points={
        "console_scripts": [
            "create-l10n-branch = mozxchannel.git.process:main",
            "import-android-l10n = mozxchannel.android.importer:main",
        ]
    },
    packages=find_packages(
        exclude=["tests"],
    ),
    tests_require=[
        "cram",
    ],
    install_requires=[
        'pygit2~=1.2.1',
        'compare-locales==8.0.0',
    ],
)
