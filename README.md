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
  * Supporting the direct expression of copy semantics where both SOURCE and TARGET arguments refer to containers.
 
#### Copy Semantics
Since ```dkrcp``` relies on ```docker cp``` its [documentation](https://docs.docker.com/engine/reference/commandline/cp/) describes the expected behavior of ```dkrcp``` when specifying a single SOURCE argument.  Therefore, ```docker cp``` explinations concerning:
  * tarball streams ' - ',
  * container's root directory treated as the current one when copying to/fromm relative paths,
  * use of the ':' as means of delimiting a container UUID/name from its associated path,
  * UID/GID permission settings
  * 

However, the following tabular form offers an equivalent but visually different presentation than the documention associated to ```docker cp```.

|         | SOURCE File  | SOURCE Directory | [SOURCE Directory Content](https://github.com/WhisperingChaos/dkrcp/blob/master/README.md#source-directory-content-an-existing-directory-path-appended-with-) | SOURCE Stream |
| :--:    | :----------: | :---------------:| :---------------: | :-------: |
| **TARGET exists as file.** | Overlay TARGET with SOURCE content. | Error |Error | Error |
| **TARGET name does not exist but its parent directory does.** | File name assumed. Copy SOURCE contents to name.| Directory name assumed. Create TARGET Directory with name and copy SOURCE "content" to it. | Identical behavior to adjacent left hand cell. | Error |
| **TARGET name does not exist, nor does its parent directory.** | Error | Error | Error | Error|
| **TARGET exists as directory.** | Copied to TARGET. | Copied to TARGET. | SOURCE content copied to TARGET. | File/Directory copied to TARGET. |
| **[TARGET assumed directory](https://github.com/WhisperingChaos/dkrcp/blob/master/README.md#target-assumed-directory-the-rightmost-last-name-of-a-specified-path-suffixed-by---it-is-assumed-to-reference-an-existing-directory) but doesn't exist.** | Error | Error | Error | Error |

######TARGET assumed directory: The rightmost, last, name of a specified [path](https://en.wikipedia.org/wiki/Path_%28computing%29) suffixed by '/'.  It is assumed to reference an existing directory.

######SOURCE Directory Content: An existing directory path appended with '/.'

The multi-SOURCE copy semantics simply converges to the row labeled: '**TARGET exists as directory.**' above.  In this situation any SOURCE type, whether it be a file, directory, or stream is successfully copied, as long as the TARGET refers to a a pre-existing directory, otherwise, it fails.  



#### Why?
  * Promotes smaller images and potentially minimizes their attack surface by selectively copying only those resources required to run the containerized application.
    * Although special effort has been applied to minimize the size of Official Docker Hub images, the inability of Docker's [builder](https://github.com/docker/docker/tree/master/builder) component to separate build time produced artifacts and their required dependencies continues to pollute the runtime image with unnecessary and potentially artifacts.  For example, images requiring build tool chains, like golang and C++, 
  * Facilitates manufacturing images by piplines that gradually evolve either toward or away from their reliance on Dockerfiles.
    *  To accelerate the adoption of Docker containers, dkrcp can enable a strategy increace developers understanding of Docker through the measured adoption by  encapsulating build tool chains reqired by their application into Docker containers.  
  * Encapsulates the reliance on and encoding of several Docker CLI calls to implement the desired functionality insulating automation incorporating this utility from potentially future improved support by Docker community members through dkrcp's interface.
