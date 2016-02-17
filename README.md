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
    --author="",-a            Specify maintainer when target is an image.
    --change[],-c             Apply specified Dockerfile instruction(s) when
                                target is an image. see 'docker commit'
    --message="",-m           Apply commit message when target is an image.
    --help=false,-h           Don't display this help message.
    --version=false           Don't display version info.
```

Supplements [```docker cp```](https://docs.docker.com/engine/reference/commandline/cp/) by:
  * Facilitating image creation/adaptation by simply copying files to either a newly specified image or an existing one.  When copying to an existing image, its state is unaffected as copy preserves its immutability by creating a new layer.
  * Enabling the specification of mutiple copy sources, including other images, to improve operational alignment with linux [```cp -a```](https://en.wikipedia.org/wiki/Cp_%28Unix%29) and minimize layer creation when TARGET refers to an image.
 
#### Copy Semantics
Since ```dkrcp``` relies on ```docker cp``` its [documentation](https://docs.docker.com/engine/reference/commandline/cp/) describes the expected behavior of ```dkrcp``` when specifying a single SOURCE argument.  However, the following table, formulated while designing dkrcp may present the semantics more clearly than the documention associated to ```docker cp```.

|         | Source File  | Source Directory | [Source Directory Content](https://github.com/WhisperingChaos/dkrcp/blob/master/README.md#source-directory-content-an-existing-directory-path-appended-by-) | Stream |
| :--:    | :----------: | :---------------:| :---------------: | :-------: |
| **Target exists as file.** | Overlay Target with Source content. | Error |Error | Error |
| **Target name does not exist but its parent directory does.** | Name assumed a file. Copy Source contents to name.| Name assumed directory. Create Target Directory with name and copy Source "content" to it. | Identical behavior to adjacent left hand cell. | Error |
| **Target name does not exist, nor does its parent directory.** | Error | Error | Error | Error|
| **Target exists as directory.** | Copied to Target. | Copied to Target. | Source content copied to Target. | File/Directory copied to Target. |
| **[Target assumed directory](https://github.com/WhisperingChaos/dkrcp/blob/master/README.md#target-assumed-directory-the-rightmost-last-name-of-a-specified-path-suffixed-by---it-is-assumed-to-reference-an-existing-directory) but doesn't exist.** | Error | Error | Error | Error |

######Target assumed directory: The rightmost, last, name of a specified [path](https://en.wikipedia.org/wiki/Path_%28computing%29) suffixed by '/'.  It is assumed to reference an existing directory.

######Source Directory Content: An existing directory path appended by '/.' 

#### Why?
  * Promotes smaller images and potentially minimizes their attack surface by selectively copying only those resources required to run the containerized application.
  * Facilitates manufacturing images by construction piplines that gradually evolve either toward or away from their reliance on Dockerfiles.
  * Encapsulates the reliance on and encoding of several Docker CLI calls to implement the desired functionality insulating automation incorporating this utility from potentially future improved support by Docker community members through dkrcp's interface.
