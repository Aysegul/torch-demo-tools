#include "THCApply.cuh"
#include "utils.h"

struct LeakyReLUUpdateOutput {
  const float slope_;

  LeakyReLUUpdateOutput(float slope): slope_(slope) {}

  __device__ __forceinline__ void operator()(float* out, float* in) {
    float x = *in;
    *out = (x > 0) ? x : x*slope_;
  }
};

// in-place variant
struct LeakyReLUUpdateOutputIP {
  const float slope_;

  LeakyReLUUpdateOutputIP(float slope): slope_(slope) {}

  __device__ __forceinline__ void operator()(float* x) {
    *x = (*x > 0) ? *x :  *x*slope_;
  }
};

static int cunn_LeakyReLU_updateOutput(lua_State *L)
{
  THCState *state = getCutorchState(L);
  THCudaTensor *input = (THCudaTensor*)luaT_checkudata(L, 2, "torch.CudaTensor");
  THCudaTensor *output = (THCudaTensor*)luaT_getfieldcheckudata(L, 1, "output", "torch.CudaTensor");

  double slope = luaT_getfieldchecknumber(L, 1, "slope");
  bool   inPlace = luaT_getfieldcheckboolean(L, 1, "inplace");

  THAssert(THCudaTensor_checkGPU(state, 2, input, output));

  if (inPlace) {
    THCudaTensor_pointwiseApply1(state, input,
                                 LeakyReLUUpdateOutputIP(slope));
    THCudaTensor_set(state, output, input);
  } else {
    THCudaTensor_resizeAs(state, output, input);
    THCudaTensor_pointwiseApply2(state, output, input,
                                 LeakyReLUUpdateOutput(slope));
  }

  THCudaCheck(cudaGetLastError());
  return 1;
}

struct LeakyReLUUpdateGradInput
{
  const float slope_;

  LeakyReLUUpdateGradInput(float slope) : slope_(slope) {}

  __device__ __forceinline__ void operator()(float* gradInput, float* input,
                                             float* gradOutput) const {
    *gradInput = (*input > 0) ? *gradOutput : *gradOutput*slope_;
  }
};

struct LeakyReLUUpdateGradInputIP
{
  const float slope_;

  LeakyReLUUpdateGradInputIP(float slope) : slope_(slope) {}

  __device__ __forceinline__ void operator()(float* gradOutput,
                                             float* input) const {
    *gradOutput = (*input > 0) ? *gradOutput : *gradOutput*slope_;
  }
};

static int cunn_LeakyReLU_updateGradInput(lua_State *L)
{
  THCState *state = getCutorchState(L);
  THCudaTensor *output = (THCudaTensor*)luaT_getfieldcheckudata(L, 1, "output", "torch.CudaTensor");
  THCudaTensor *input = (THCudaTensor*)luaT_checkudata(L, 2, "torch.CudaTensor");
  THCudaTensor *gradOutput = (THCudaTensor*)luaT_checkudata(L, 3, "torch.CudaTensor");
  THCudaTensor *gradInput = (THCudaTensor*)luaT_getfieldcheckudata(L, 1, "gradInput", "torch.CudaTensor");

  double slope = luaT_getfieldchecknumber(L, 1, "slope");
  bool   inPlace   = luaT_getfieldcheckboolean(L, 1, "inplace");

  THAssert(THCudaTensor_checkGPU(state, 4, input, output, gradInput, gradOutput));

  if (inPlace) {
    THCudaTensor_pointwiseApply2(state, gradOutput, input,
                                 LeakyReLUUpdateGradInputIP(slope));
    THCudaTensor_set(state, gradInput, gradOutput);
  } else {
    THCudaTensor_resizeAs(state, gradInput, output);
    THCudaTensor_pointwiseApply3(state, gradInput, input, gradOutput,
                                 LeakyReLUUpdateGradInput(slope));
  }

  THCudaCheck(cudaGetLastError());
  return 1;
}

static const struct luaL_Reg cunn_LeakyReLU__ [] = {
  {"LeakyReLU_updateOutput", cunn_LeakyReLU_updateOutput},
  {"LeakyReLU_updateGradInput", cunn_LeakyReLU_updateGradInput},
  {NULL, NULL}
};

void cunn_LeakyReLU_init(lua_State *L)
{
  luaT_pushmetatable(L, "torch.CudaTensor");
  luaT_registeratname(L, cunn_LeakyReLU__, "nn");
  lua_pop(L,1);
}
