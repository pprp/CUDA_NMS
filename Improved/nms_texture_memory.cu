/*
author:pprp
dec: texture<DataType,Type,ReadMode) texRef;
	- DataType：制定纹理存储起获取时返回的数据类型，DataType限制为基本的整形和
	  单精度浮点行，或者向量类型，所以这里的结构体是不可以使用的。
*/

#include <stdio.h>
#include <cuda_runtime.h>
#include <iostream>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include "opencv2/imgproc/imgproc.hpp"
#include "device_launch_parameters.h"
#include <stdlib.h>
#include "string"

using namespace cv;
using namespace std;

const int N = 19;

#define HANDLE_ERROR(ans) { gpuAssert((ans), __FILE__, __LINE__); }

inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
	if (code != cudaSuccess)
	{
		fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
		if (abort) exit(code);
	}
}

typedef struct
{
	double x,y,w,h;
	char s[100];
	char cls[100];
	double cmps;
}box;

texture<box> bs;

__device__ float IOUcalc(box b1, box b2)
{
	float ai = (float)(b1.w + 1)*(b1.h + 1);
	float aj = (float)(b2.w + 1)*(b2.h + 1);
	float x_inter, x2_inter, y_inter, y2_inter;

	x_inter = max(b1.x,b2.x);
	y_inter = max(b1.y,b2.y);

	x2_inter = min((b1.x + b1.w),(b2.x + b2.w));
	y2_inter = min((b1.y + b1.h),(b2.y + b2.h));

	float w = (float)max((float)0, x2_inter - x_inter);
	float h = (float)max((float)0, y2_inter - y_inter);

	float inter = ((w*h)/(ai + aj - w*h));
	return inter;
}

__global__ void NMS_GPU0(box *dev_b, bool *d_res)
{
	int abs_y = blockIdx.y * blockDim.y + threadIdx.y;
	int abs_x = blockIdx.x * blockDim.x + threadIdx.x;

	float theta = 0.1;
	if(dev_b[abs_x].cmps < dev_b[abs_y].cmps)
	{
		if(IOUcalc(dev_b[abs_y],dev_b[abs_x])>theta)
		{
			d_res[abs_x] = false;
		}
	}
}

__global__ void NMS_GPU1(box*dev_b,bool * d_res)
{
	__shared__ box blocka[N];
	//__shared__ box blockb[N];

	unsigned int xIndex = blockIdx.x * blockDim.x + threadIdx.x;

	if(xIndex < N)
	{
		blocka[threadIdx.x] = dev_b[xIndex];
	}

	__syncthreads();

	xIndex = blockIdx.x * blockDim.x + threadIdx.x;

	float theta = 0.1;
	for(int i = 0 ; i < N ; i++)
	{
		if(i != xIndex)
		{
			if(blocka[i].cmps < blocka[xIndex].cmps)
			{
				if(IOUcalc(blocka[i],blocka[xIndex]) > theta)
				{
					d_res[i] = false;
				}
			}
		}
	}
}

__global__ void NMS_GPU2(box*dev_b,bool * d_res)
{
	unsigned int xIndex = blockIdx.x * blockDim.x + threadIdx.x;

	float theta = 0.1;
	for(int i = 0 ; i < N ; i++)
	{
		if(i != xIndex)
		{
			if(dev_b[i].cmps < dev_b[xIndex].cmps)
			{
				if(IOUcalc(dev_b[i],dev_b[xIndex]) > theta)
				{
					d_res[i] = false;
				}
			}
		}
	}
}

/*
__global__ static void NMS_GPU3(bool *d_res)
{
	unsigned int xIndex = blockIdx.x * blockDim.x + threadIdx.x;
	float theta = 0.1;
	for (int i = 0; i < N; i++)
	{
		if(i != xIndex)
		{
			if (con_box[i].cmps < con_box[xIndex].cmps)
			{
				if (IOUcalc(con_box[i], con_box[xIndex]) > theta)
				{
					d_res[i] = false;
				}
			}
		}
	}
}
*/
__global__ void NMS_GPU4(bool * d_res)
{
	unsigned int xIndex = blockIdx.x * blockDim.x + threadIdx.x;
	float theta = 0.1;
	for (int i = 0; i < N; i++)
	{
		if(i != xIndex)
		{
			box tex1=tex1Dfetch(bs,i);
			box tex2=tex1Dfetch(bs,xIndex);

			if (tex1.cmps < tex2.cmps)
			{
				if (IOUcalc(tex1, tex2) > theta)
				{
					d_res[i] = false;
				}
			}
		}
	}
}

int main()
{
	int count = N;
	Mat temp = imread("/home/learner/cuda-workspace/Parallel_NMS/Cow_45.jpg",1);

	bool *h_res =(bool*)malloc(sizeof(bool)*count);

	for(int i=0; i<count; i++)
	{
		h_res[i] = true;
	}

	box b[N];
	b[0].x = 996.000000;b[0].y = 2566.420000;b[0].w = 170.793000;b[0].h=172.580000;
	strcpy(b[0].cls,"nose");strcpy(b[0].s,"0.983194");b[0].cmps=0.983194;
	b[1].x = 4238.937000;b[1].y = 1594.513000;b[1].w = 160.063000;b[1].h=148.487000;
	strcpy(b[1].cls,"eye");strcpy(b[1].s,"0.992166");b[1].cmps=0.992166;
	b[2].x = 4656.389000;b[2].y = 2175.186000;b[2].w = 316.180000;b[2].h=221.552000;
	strcpy(b[2].cls,"nose");strcpy(b[2].s,"0.994816");b[2].cmps=0.994816;
	b[3].x = 4316.000000;b[3].y = 1660.000000;b[3].w = 127.474000;b[3].h=113.452000;
	strcpy(b[3].cls,"eye");strcpy(b[3].s,"0.990833");b[3].cmps=0.990833;
	b[4].x = 997.013000;b[4].y = 2664.408000;b[4].w = 222.214000;b[4].h=229.068000;
	strcpy(b[4].cls,"nose");strcpy(b[4].s,"0.985067");b[4].cmps=0.985067;
	b[5].x = 666.069000;b[5].y = 2029.219000;b[5].w = 135.689000;b[5].h=160.833000;
	strcpy(b[5].cls,"eye");strcpy(b[5].s,"0.993240");b[5].cmps=0.993240;
	b[6].x = 4653.547000;b[6].y = 2324.000000;b[6].w = 338.125000;b[6].h=133.902000;
	strcpy(b[6].cls,"nose");strcpy(b[6].s,"0.982858");b[6].cmps=0.982858;
	b[7].x = 4476.556000;b[7].y = 2131.557000;b[7].w = 253.402000;b[7].h=273.601000;
	strcpy(b[7].cls,"nose");strcpy(b[7].s,"0.959098");b[7].cmps=0.959098;
	b[8].x = 754.326000;b[8].y = 2571.066000;b[8].w = 324.674000;b[8].h=161.605000;
	strcpy(b[8].cls,"nose");strcpy(b[8].s,"0.993699");b[8].cmps=0.993699;
	b[9].x = 729.962000;b[9].y = 2658.741000;b[9].w = 349.038000;b[9].h=192.046000;
	strcpy(b[9].cls,"nose");strcpy(b[9].s,"0.986209");b[9].cmps=0.986209;
	b[10].x = 1271.863000;b[10].y = 2058.679000;b[10].w = 138.781000;b[10].h=137.553000;
	strcpy(b[10].cls,"eye");strcpy(b[10].s,"0.989965");b[10].cmps=0.989965;
	b[11].x = 4316.000000;b[11].y = 1601.751000;b[11].w = 134.204000;b[11].h=141.249000;
	strcpy(b[11].cls,"eye");strcpy(b[11].s,"0.988307");b[11].cmps=0.988307;
	b[12].x = 650.901000;b[12].y = 2032.621000;b[12].w = 91.484000;b[12].h=42.112000;
	strcpy(b[12].cls,"eye");strcpy(b[12].s,"0.969982");b[12].cmps=0.969982;
	b[13].x = 1328.000000;b[13].y = 2058.692000;b[13].w = 103.849000;b[13].h=136.518000;
	strcpy(b[13].cls,"eye");strcpy(b[13].s,"0.987316");b[13].cmps=0.987316;
	b[14].x = 214.809000;b[14].y = 1599.809000;b[14].w = 1553.705000;b[14].h=1319.679000;
	strcpy(b[14].cls,"head");strcpy(b[14].s,"0.997623");b[14].cmps=0.997623;
	b[15].x = 3826.177000;b[15].y = 1072.206000;b[15].w = 1254.063000;b[15].h=1412.903000;
	strcpy(b[15].cls,"head");strcpy(b[15].s,"0.997487");b[15].cmps=0.997487;
	b[16].x = 729.632000;b[16].y = 2578.523000;b[16].w = 442.495000;b[16].h=302.378000;
	strcpy(b[16].cls,"nose");strcpy(b[16].s,"0.960093");b[16].cmps=0.960093;
	b[17].x = 655.430000;b[17].y = 2031.151000;b[17].w = 91.570000;b[17].h=148.691000;
	strcpy(b[17].cls,"eye");strcpy(b[17].s,"0.993275");b[17].cmps=0.993275;
	b[18].x = 4251.712000;b[18].y = 1660.000000;b[18].w = 147.288000;b[18].h=105.309000;
	strcpy(b[18].cls,"eye");strcpy(b[18].s,"0.992576");b[18].cmps=0.992576;

	//box *dev_b;
	bool *d_res;

	//gpu start time
	cudaEvent_t start, stop;
	HANDLE_ERROR(cudaEventCreate(&start));
	HANDLE_ERROR(cudaEventCreate(&stop));
	HANDLE_ERROR(cudaDeviceSynchronize());
	float gpu_time = 0.0f;
	cudaEventRecord(start,0);
	//gpu start time

	HANDLE_ERROR(cudaMalloc((void**)&d_res, count*sizeof(bool)));
	HANDLE_ERROR(cudaMemcpy(d_res, h_res,sizeof(bool)*count, cudaMemcpyHostToDevice));

	//HANDLE_ERROR(cudaMalloc((void**)&dev_b,sizeof(box)*count));
	//HANDLE_ERROR(cudaMemcpy(dev_b, b,sizeof(box)*count, cudaMemcpyHostToDevice));
	HANDLE_ERROR(cudaBindTexture(NULL,bs,b,sizeof(box)*count));


	NMS_GPU4<<<dim3(1,count,1),count>>>(d_res);

	cudaThreadSynchronize();

	HANDLE_ERROR(cudaMemcpy(h_res, d_res, sizeof(bool)*count, cudaMemcpyDeviceToHost));

	//gpu end time
	cudaEventRecord(stop,0);
	unsigned long int counter = 0;
	while(cudaEventQuery(stop) == cudaErrorNotReady)
	{
		counter++;
	}
	HANDLE_ERROR(cudaEventElapsedTime(&gpu_time, start, stop));
	printf("GPU executed time: %.2f (ms)\n", gpu_time);
	printf("CPU executed %lu iterations while waiting for GPU to finish\n", counter);
	cudaEventDestroy(start);
	cudaEventDestroy(stop);

	cudaUnbindTexture(bs);

	for(int i =0; i<N ; i++)
	{
		if(*(h_res+i) == true)
		{
			printf("GPU Draw: %d--%d\n",i,*(h_res+i));
			putText(temp,b[i].cls,Point((int)b[i].x,(int)b[i].y-5),cv::FONT_HERSHEY_SIMPLEX,1.7,Scalar(255,255,255),5,8,0);
			putText(temp,b[i].s,Point((int)b[i].x+120,(int)b[i].y-5),cv::FONT_HERSHEY_SIMPLEX,1.7,Scalar(255,255,255),5,8,0);
			rectangle(temp,Point((int)b[i].x,(int)b[i].y),Point((int)b[i].x + (int)b[i].w,(int)b[i].y + (int)b[i].h),Scalar(92.185,194),8,8,0);
		}
	}
	namedWindow("Window",0);
	resizeWindow("Window",1064,800);
	imshow("Window",temp);
	waitKey(0);
	return 0;
}
