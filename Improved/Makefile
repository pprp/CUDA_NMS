
OPENCV_LIBPATH=-I/usr/local/lib -I/usr/local/lib/x86_64-linux-gnu/

OPENCV_INCLUDEPATH=-I/usr/local/include,-I/usr/local/include/opencv

OPENCV_LIBS=-lopencv_core -lopencv_imgproc -lopencv_highgui

CUDA_INCLUDEPATH=/usr/local/cuda-8.0/include

NVCC_OPTS=-O3 -arch=sm_20 -Xcompiler -Wall -Xcompiler -Wextra -m64

GCC_OPTS=-O3 -Wall -Wextra -m64

nms: nms.o
	nvcc -o nms nms_constant_memory.o -L $(OPENCV_LIBPATH) $(OPENCV_LIBS) $(NVCC_OPTS)

nms.o: nms_constant_memory.cu
	nvcc -c nms_constant_memory.cu $(OPENCV_INCLUDEPATH)


clean:
	rm -f *.o *.png hw
