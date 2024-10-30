# PARSE OPTIONS FOR CLEAN LIBRARY BUILDS ####################################

clean_hypre=false
clean_sundials=false
ARG=""

# Loop through the options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean-hypre)
            clean_hypre=true  # Set the flag to true when --clean-hypre is used
            shift
            ;;
        --clean-sundials)
            clean_sundials=true
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
	    ARG="${ARG} $1"  # Append unrecognized arguments to ARG
            shift
            ;;
    esac
done

# Trim leading spaces from ARG, if necessary
ARG="${ARG#"${ARG%%[![:space:]]*}"}"

if [ "$clean_hypre" = true ]; then
    echo "Option --clean-hypre is set."
fi

if [ "$clean_sundials" = true ]; then
    echo "Option --clean-sundials is set."
fi

# FINISHED WITH CLEANING OPTIONS ###########################################

# Decide compilers
echo "Before setting tpt comp"
source ../Scripts/set_thirdparty_compilers.sh

# build hypre
source ../Scripts/HYPRE/build_hypre.sh confmake.sh $clean_hypre

## build sundials
source ../Scripts/SUNDIALS/build_sundials.sh confmake.sh $clean_sundials


# Use ARG and the options
#echo "ARG is: $ARG"
if [ "$SOURCE_INTEL_IFORT" -eq 1 ]; then
   source ../Scripts/set_intel_compiler.sh $ARG
fi   
