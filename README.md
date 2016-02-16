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
  * Facilitating image creation/adaptation by simply copying files to either a newly specified image name or an existing one.  When copying to an existing image, its layers are unaffected as copy preserves its immutability by creating a new layer.
  * Enabling the specification of mutiple copy sources, including other images, improving operational alignment with the linux [```cp -a```](https://en.wikipedia.org/wiki/Cp_%28Unix%29).

# Why?
  * Promotes smaller images and potentially minimizes their attack surface by selectively copying only those resources required to run the containerized application.
  * Facilitates manufacturing images using construction piplines that potentially eliminate the need for Dockerfiles.
  * Encapsulates the necessary implementation of several docker CLI calls elmiminating the redundant encoding 
