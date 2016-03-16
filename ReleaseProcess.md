

New Release Process:
* In new host directory:
  * ```git clone https://github.com/WhisperingChaos/dkrcp```
  * ```git remote set-url origin git@github.com:WhisperingChaos/dkrcp.git```
* Change existing files in Release-Test environment:
  * ```UcpInclude.sh``` ensure its dependent component versions are correct.
  * ```dkrcp_Test.sh``` must reflect the same version number as ```UcpInclude.sh```.
* Test the current master branch:
  * Verify that selected versions are reflected by:
    * ```dkrcp --version```
    * ```dkrcp_Test.sh --version```
  * Run the integration tests within container:
    * Use docker:dind to create test environments for each major version of Docker.
    * ```drkrcp_Test.sh``` 
  * Iterate testing till happy.
* Create a new dkrcp git tag:
  * Determine dkrcp version.
  * Create annotated tag:
    * ```git tag -a <dkrcp version> -m "dkrcp: <dkrcp version>"```
  * Push tag to github:
    * ```git push origin --tag # new tag```
* Repeat New Release Process until nothing needs to be changed.
