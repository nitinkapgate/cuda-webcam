#ifndef TEX_INVERT_CU
#define TEX_INVERT_CU

#include "texAbsDiff.h"

texture<float4, 2, cudaReadModeElementType> texAbsDiff1;

#define BLOCK_SIZE_X (32)
#define BLOCK_SIZE_Y (32)

#define ENABLE_TIMING_CODE 1


// abs
inline __host__ __device__ float4 abs( float4 a )
{	
	return make_float4( fabsf( a.x ), fabsf( a.y ), fabsf( a.z ), fabsf( a.w ) );
}


__global__
void gpuTexAbsDiff(
	float* image,
	int width,
	int height
	)
{
	// threade ait sat�r ve s�tunu hesapla.
	int row = blockIdx.y * BLOCK_SIZE_Y + threadIdx.y;
	int col = blockIdx.x * BLOCK_SIZE_X + threadIdx.x;

	// global memorydeki imaj i�in indisi hesapla.
	int cIdx = ( row * width + col ) * 3; // 3 ile �arp�m RGB i�in, linearIndex.

	float tw = 1.0f / width; // Texture kordinatlar�nda 1 pixel geni�lik.
	float th = 1.0f / height; // Texture kordinatlar�nda 1 pixel y�kseklik.

	// merkez piksel kordinat�n normalize texel kordinatlar�n� hesapla.
	float tu = ( float )col * tw;
	float tv = ( float )row * th;

	/*tw *= 4;
	th *= 4;*/
	
	// row, col etraf�ndaki 4 ana y�ndeki texelden farklar�n� al.
	float4 texVal1 = tex2D( texAbsDiff1, tu, tv ) - tex2D( texAbsDiff1, tu + tw, tv + th );
	float4 texVal2 = tex2D( texAbsDiff1, tu, tv ) - tex2D( texAbsDiff1, tu - tw, tv - th );
	float4 texVal3 = tex2D( texAbsDiff1, tu, tv ) - tex2D( texAbsDiff1, tu + tw, tv - th );
	float4 texVal4 = tex2D( texAbsDiff1, tu, tv ) - tex2D( texAbsDiff1, tu - tw, tv + th );

	// 4 ana y�ndeki farklar�n mutlak de�erlerinin ortalamas�n� al.
	float4 texVal = 0.25f * ( abs( texVal1 ) + abs( texVal2 ) + abs( texVal3 ) + abs( texVal4 ) );

	// global memorydeki imaja hesaplanan de�erleri aktar.
	*( image + cIdx )     = texVal.x;
	*( image + cIdx + 1 ) = texVal.y;
	*( image + cIdx + 2 ) = texVal.z;
}

void deviceTexAbsDiffLaunch(
	float *d_Image,
	int width,
	int height
	)
{
	 // launch kernel
	dim3 dimBlock( BLOCK_SIZE_X, BLOCK_SIZE_Y );
    dim3 dimGrid( width / dimBlock.x, height / dimBlock.y );

#if ENABLE_TIMING_CODE

	cudaEvent_t start, stop;
	cudaEventCreate(&start);
	cudaEventCreate(&stop);
	cudaEventRecord(start, 0);

#endif

    gpuTexAbsDiff<<< dimGrid, dimBlock >>>( d_Image, width, height);

#if ENABLE_TIMING_CODE
	cudaEventRecord(stop, 0);
	cudaEventSynchronize(stop);
	float elapsedTime;
	cudaEventElapsedTime(&elapsedTime, start, stop);

    // block until the device has completed
    cudaThreadSynchronize();
	
	printf("gpuTexAbsDiff kernel time: %.3f ms\n", elapsedTime);
#endif

	cudaThreadSynchronize();

    // check if kernel execution generated an error
    // Check for any CUDA errors
    checkCUDAError("kernel invocation");
}


#endif