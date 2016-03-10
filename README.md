# dkrcp
Copy files between host's file system, containers, and images.
#####ToC
[Copy Semantics](#copy-semantics)  
&nbsp;&nbsp;&nbsp;&nbsp;[Images as SOURCE/TARGET](#images-as-sourcetarget)  
&nbsp;&nbsp;&nbsp;&nbsp;[Interweaved Copying](#interweaved-copying)  
&nbsp;&nbsp;&nbsp;&nbsp;[Permissions](permissions)  
[Installing](#install)  
[Testing](#testing)  
[Motivation](#motivation)

```
Usage: ./dkrcp.sh [OPTIONS] SOURCE [SOURCE]... TARGET 

  SOURCE - Can be either: 
             host file path     : {<relativepath>|<absolutePath>}
             image file path    : [<nameSpace>/...]{<repositoryName>:[<tagName>]|<UUID>}::{<relativepath>|<absolutePath>}
             container file path: {<containerName>|<UUID>}:{<relativepath>|<absolutePath>}
             stream             : -
  TARGET - See SOURCE.

  Copy SOURCE to TARGET.  SOURCE or TARGET must refer to either a container/image.
  <relativepath> within the context of a container/image is relative to
  container's/image's '/' (root).

OPTIONS:
    --ucpchk-reg=false        Don't pull images from registry. Limits image name
                                resolution to Docker local repository for  
                                both SOURCE and TARGET names.
    --author="",-a            Specify maintainer when TARGET is an image.
    --change[],-c             Apply specified Dockerfile instruction(s) when
                                TARGET is an image. see 'docker commit'
    --message="",-m           Apply commit message when TARGET is an image.
    --help=false,-h           Don't display this help message.
    --version=false           Don't display version info.
```

Supplements [```docker cp```](https://docs.docker.com/engine/reference/commandline/cp/) by:
  * Facilitating image creation or adaptation by simply copying files.  When copying to an existing image, its state is unaffected, as copy preserves its immutability by creating a new layer.
  * Enabling the specification of mutiple copy sources, including other images, to improve operational alignment with linux [```cp -a```](https://en.wikipedia.org/wiki/Cp_%28Unix%29) and minimize layer creation when TARGET refers to an image.
  * Supporting the direct expression of copy semantics where SOURCE and TARGET arguments concurrently refer to containers.
 
#### Copy Semantics
```dkrcp``` relies on ```docker cp```, therefore, ```docker cp```'s [documentation](https://docs.docker.com/engine/reference/commandline/cp/) describes much of the expected behavior of ```dkrcp```, especially when specifying a single SOURCE argument.  Due to this reliance ```docker cp``` explinations concerning:
  * tarball streams ' - ',
  * container's root directory treated as the current one when copying to/from relative paths,
  * working directory of ```docker cp``` anchoring relative host file system paths,
  * desire to mimic ```cp -a``` recursive navigation and preserve file permissions,
  * ownership UID/GID permission settings when copying to/from containers, 
  * use of ':' as means of delimiting a container UUID/name from its associated path,
  * inability to copy certain files,

are all applicable to ```dkrcp```.

However, the following tabular form offers an equivalent description of copy behavior but visually different than the documention associated to ```docker cp```.

|         | SOURCE File  | SOURCE Directory | [SOURCE Directory Content](https://github.com/WhisperingChaos/dkrcp/blob/master/README.md#source-directory-content-an-existing-directory-path-appended-with-) | SOURCE Stream |
| :--:    | :----------: | :---------:| :----------: | :----------: |
| **TARGET exists as file.** | Copy SOURCE content to TARGET. | Error |Error | Error |
| **TARGET name does not exist but its parent directory does.** | TARGET File name assumed. Copy SOURCE content to TARGET.| TARGET directory name assumed. Create TARGET directory. Copy SOURCE content to TARGET. | Identical behavior to adjacent left hand cell. | Error |
| **TARGET name does not exist, nor does its parent directory.** | Error | Error | Error | Error|
| **TARGET exists as directory.** | Copy SOURCE to TARGET. | Copy SOURCE to TARGET. | Copy SOURCE content to TARGET. | Copy File/Directory to TARGET. |
| **[TARGET assumed directory](https://github.com/WhisperingChaos/dkrcp/blob/master/README.md#target-assumed-directory-the-rightmost-last-name-of-a-specified-path-suffixed-by---it-is-assumed-to-reference-an-existing-directory) doesn't exist but its parent directory does.** | Error | Copy SOURCE content to TARGET. | Copy SOURCE content to TARGET. | Error |

######TARGET assumed directory: The rightmost, last, name of a specified [path](https://en.wikipedia.org/wiki/Path_%28computing%29) suffixed by '/' - indicative of a directory.

######SOURCE Directory Content: An existing directory path appended with '/.'.

The multi-SOURCE copy semantics simply converge to the row labeled: '**TARGET exists as directory.**' above.  In this situation any SOURCE type, whether it a file, directory, or stream is successfully copied, as long as the TARGET refers to a preexisting directory, otherwise, the operation fails.

##### Images as SOURCE/TARGET
A double colon '```::```' delimiter classifies the file path as referring to an image, differenciating it from the single one denoting a container reference.  Therefore, an argument referencing an image involving a tag would appear similar to: '```repository_name:tag::etc/hostname```'.

When processing image arguments, ```dkrcp``` perfers binding to images known locally to Docker Engine that match the provided name and will ignore remote ones unless directed to include them.  To search remote registries, specify the option: ```--ucpchk-reg=true```.  Enabling this feature will cause ```dkrcp``` to initiate ```docker pull``` iff the specified image name is not locally known.  Note, when enabled, ```--ucpchk-reg``` applies to both SOURCE and TARGET image references. Therefore, in situations where the TARGET image name doesn't match a locally existing image but refers to an existing remote image, this remote image will be pulled and become the one referenced by TARGET.

Since copying to an existing TARGET image first applies this operation to a derived container (an image replica), its effects are "reversible".  Failures involving existing images simply delete the derived container leaving the repository unchanged.  However, when adding a new image to the local repository, the repository's state is first updated to reflect a [```scratch```](https://docs.docker.com/engine/userguide/eng-image/baseimages/#creating-a-simple-base-image-using-scratch) version of the image.  This ```scratch``` image is then updated in the same way as any existing TARGET image.  In this situation, a failure removes both the container and ```scratch``` image reverting the local repository's state.

######Copy *from* an *existing image*:
  * Convert the referenced image to a container via [```docker create```](https://docs.docker.com/engine/reference/commandline/create).
  * Copy from this container using ```docker cp```.
  * Destroy this container using ```docker rm```.

######Copy *to* an *existing image*:
  * Convert the referenced image to a container via ```docker create```.
  * Copy to this container using ```docker cp```.
    * When both the SOURCE and TARGET involve containers, the initial copy strategy streams ```docker cp``` output of the SOURCE container to a receiving ```docker cp``` that accepts this output as its input to the TARGETed container.  As long as the TARGET references an existing directory, the copy succeeds completing the operation.  However, if this copy strategy should fail, a second strategy executes a series of ```docker cp``` operations.  The first copy in this series, replicates the SOURCE artifacts to a temporary directory in the host environment executing ```dkrcp```.  A second ```docker cp``` then relays this SOURCE replica to the TARGET container.
  * If copy succeeds, ```dkrcp``` converts this container's state to an image using [```docker commit```](https://docs.docker.com/engine/reference/commandline/commit/).  
    * Specifying an image name as a TARGET argument propagates this name to ```docker commit``` superseding the originally named image.
    * When processing multiple SOURCE arguments, ```dkrcp``` delays the commit until after iterating over all of them.
  * If copy fails, ```dkrcp``` bypasses the commit.
  * Destroy this container using ```docker rm```.

######Copy *to create* an *image*:
  * Execute a ```docker build``` using [```FROM scratch```](https://docs.docker.com/engine/userguide/eng-image/baseimages/#creating-a-simple-base-image-using-scratch).
  * Continue with [Copy *to* an *existing image*](https://github.com/WhisperingChaos/dkrcp/blob/master/README.md#copy-to-an-existing-image).

#####Interweaved Copying
The behavior of ```dkrcp``` in situations where the same container assumes both SOURCE and TARGET roles is undefined and may change.  Preliminary testing indicates that non-overlapping directory references are copied as expected.  In fact, a fully overlapping root to root copy operation succeeds but no time has been invested to determine its correctness.  Therefore, exercise caution when copying between the same SOURCE and TARGET containers.  Fortunately copy operations involving the same SOURCE and TARGET image avert this uncertainty.

When operating on the same SOURCE and TARGET image, ```dkrcp``` converts both to independent container instances.  The use of independent container prevents entanglement of the copy streams.  Therefore ```dkrcp```'s behavior should be identical to: copy from source container to host then copy from host to target container.

#####Permissions
Since ```dkrcp``` wraps ```docker cp``` it applies file system permissions according to ```docker cp``` semantics.  ```docker cp``` currently replaces Linux UID and GID file system settings with the UID and GID of the account executing ```docker cp``` when copying from a container.  It then reverses this behavior when copying to a TARGET container, by replacing both the SOURCE UID and GID with the Linux root ID ('1').  Therefore, these permission semantics will eliminate custom file permissions applied to SOURCE or TARGET file system objects.  These same permission semantics apply to images.  

####Install
#####Dependencies
  * GNU Bash 4.0+
  * Docker Engine 1.8+

#####Instructions

  * Select/create the desired directory to contain this project's git repository.
  * Use ```cd``` command to make this directory current.
  * Depending on what you wish to install execute:
    * ```git clone``` to copy entire project contents including the git repository.  Obtains current master which may include untested features.
    * [```git archive```](https://www.kernel.org/pub/software/scm/git/docs/git-archive.html) to copy only the necessary project files without the git repository.  Archive can be selective by specifying tag or branch name.
    *  wget https://github.com/whisperingchaos/dkrcp/zipball/master creates a zip that includes only the project files without the git repository.  Obtains current master branch which may include untested features.
  * Selectively add the 'dkrcp' alias by running [alias_Install.sh](https://github.com/WhisperingChaos/dkrcp/blob/master/alias_Install.sh).
 
#####Development Environment
  * Ubuntu 12.04
  * GNU Bash 4.2.25(1)-release
  * Docker Engine 1.9.1
  * [jq 1.5](https://stedolan.github.io/jq)

####Testing
Execution of ```dkrcp```'s test program: ```dkrcp_Test.sh```, ensures its proper operation within its installed host environment.  Since ```dkrcp_Test.sh``` must affect the local repository to verify ```dkrcp```'s operation, it first performs a scan of the local environment to determine if its produced artifacts overlap existing file system and Docker repository ones.  The scan operation will generate a report and terminate testing upon detection of overlapping artifacts.  Please note that all testing artifact names begin with the ```dkrcp_test``` namespace, so it's unlikely image or file names in the host environment will collide with ones generated during testing.
#####Test Dependencies
  *  [```dkrcp``` Dependencies](#dependencies)
  *  jq 1.5
```
   # without any parameters checks dependencies, scans for remnants, 
   # cleans the environment before starting, and executes every test.
   > ./drkcp_Test.sh 
   # dependency checking examines the local repository for existing
   # images and containers.  if the repository isn't empty, the
   # script terminates before running any test.  if this occurs,
   # run the following:
   > ./dkrcp_Test.sh --no-depend

```

####Motivation
  * Promotes smaller images and potentially minimizes their attack surface by selectively copying only those resources required to run the containerized application when creating the runtime image.
    * Use one or more Dockerfiles to generate the artifacts needed by the application.
    * Use ```dkrcp``` to copy the desired runtime artifacts from these containers/images and create the essential runtime image.
  * Facilitates building applications by piplines that gradually incorporate Docker containers.
    *  Existing build pipelines can replace locally installed build tool chains with Docker Hub provided build tool chain images, such as [golang](https://hub.docker.com/_/golang/).  The Docker Hub containerized versions potentially elimiate the need to physically install/configure a locally hosted tool chain and fully isolate build processes to ensure their repeatability.  Once a containerized build process completes, its desired artifacts can then be transferred from the resultant container/image to a host file result directory using ```dkrcp```.
  * Encapsulates the reliance on and encoding of several Docker CLI calls to implement the desired functionality insulating automation incorporating this utility from potentially future improved support by Docker community members through dkrcp's interface.

###License

The MIT License (MIT) Copyright (c) 2015-2016 Richard Moyse License@Moyse.US

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

###Legal Notice

Docker and the Docker logo are trademarks or registered trademarks of Docker, Inc. in the United States and/or other countries. Docker, Inc. and other parties may also have trademark rights in other terms used herein.
