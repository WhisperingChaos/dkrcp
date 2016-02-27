# dkrcp
Copy files between host's file system, containers, and images.
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
A double colon '```::```' delimiter classifies the file path as referring to an image, differenciating it from the single one denoting a container reference.  Therefore, an argument referencing an image involving a tag would appear similar to: '```image_name:image_tag::etc/hostname```'.

######Copying *from* an *existing image*:
  * Convert the referenced image to a container via [```docker create```](https://docs.docker.com/engine/reference/commandline/create).
  * Copy from this container using ```docker cp```.
  * ```dkrcp``` destroys this container using ```docker rm```.

######Copying *to* an *existing image*:
  * Convert the referenced image to a container via ```docker create```.
  * Copy to this container using ```docker cp```.
  * If copy succeeds, ```dkrcp``` converts this container's state to an image using ```docker commit```.  
    * Specifying an image name as a TARGET argument propagates this name to ```docker commit``` superseding the originally named image.
    * When processing multiple SOURCE arguments, ```dkrcp``` delays the commit until after iterating over all of them.
  * If copy fails, ```dkrcp``` bypasses the commit.
  * ```dkrcp``` destroys this container using ```docker rm```.
  

#### Why?
  * Promotes smaller images and potentially minimizes their attack surface by selectively copying only those resources required to run the containerized application.
    * Although special effort has been applied to minimize the size of Official Docker Hub images, the inability of Docker's [builder](https://github.com/docker/docker/tree/master/builder) component to separate build time produced artifacts and their required dependencies continues to pollute the runtime image with unnecessary artifacts increasing the runtime container's attack surface.  For example, images requiring build tool chains, like golang and C++, incorporate compilers, linkers, dependent libraries, ... into their files systems.  At best these tool chain resources can be 'logically' removed from the file system through their deletion.  These and other file system artifacts employed by the build, like C++ object files, will remain accessible in the runtime file system if not properly removed by the build process.  
  * Facilitates manufacturing images by piplines that gradually evolve either toward or away from their reliance on Dockerfiles.
    *  To accelerate the adoption of Docker containers, strategies dkrcp can enable a strategy increace developers understanding of Docker through the measured adoption by  encapsulating build tool chains reqired by their application into Docker containers.  
  * Encapsulates the reliance on and encoding of several Docker CLI calls to implement the desired functionality insulating automation incorporating this utility from potentially future improved support by Docker community members through dkrcp's interface.
