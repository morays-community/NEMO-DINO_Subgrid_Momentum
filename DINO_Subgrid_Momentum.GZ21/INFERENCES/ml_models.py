import numpy as np
from numpy.matrixlib import bmat
import torch, einops
import sys
sys.path.append('ZB-DINO')

from models.LitParamModel import LitParamModel
from csvflowdatamodule.CsvDataModule import CsvDataModule

from lightning.pytorch.cli import LightningCLI

path_par_model ='ZB-DINO/config/model/simple2D.yaml'
path_par_data ='ZB-DINO/config/data/subgrid_V1.yaml'
path_model = 'ZB-DINO/weights/91xee3n1/checkpoints/last.ckpt'

#       Utils
# -----------------
def Is_None(*inputs):
    """ Test presence of at least one None in inputs """
    return any(item is None for item in inputs)


@torch.no_grad()
def model_loading(weights_path=path_model, path_config_model=path_par_model, path_config_data=path_par_data, device='cpu') :
    cli = LightningCLI(LitParamModel,
                     datamodule_class=CsvDataModule,
                     args=["-c", path_config_data, "-c", path_config_model], run=False)
    cli.model.load_state_dict(torch.load(path_model, weights_only=True)['state_dict'])
    cli.model.to(device)
    return cli


#       Main Model Routines
# ------------------------------
# use GPUs if available
if torch.cuda.is_available():
    print("CUDA Available")
    device = torch.device('cuda')
else:
    print('CUDA Not Available')
    device = torch.device('cpu')


# Load model
cli = model_loading(device=device)

# Predictions
@torch.no_grad()
def momentum_cnn(u, v, mask_u, mask_v, sampling=True):
    """ Take as input u and v fields and return forcing fields using GZ (2021)

    Param :
        u (i, j, k)
        v (i, j, k)
        mask_u (i j k)
        mask_v (i j k)
        sampling (bool) : to add random noise or not
    Out :
        Su (i j k)
        Sv (i j k)
    """
    if Is_None([u, v]):
        return None
    else:
        global cli, u_scale, v_scale, Su_scale, Sv_scale, device

        batch = {}

        cvt = lambda f, mf : torch.tensor(einops.rearrange(f.astype(np.float32)*mf.astype(np.float32), 'i j k -> 1 k i j')).to(device)
        batch['CoarsedU'] = cvt(u, mask_u)
        batch['CoarsedV'] = cvt(v, mask_v)

        batch = cli.datamodule.transforms.val.__call__(batch)
        # preds
        ret = cli.model(batch)

        # renormalize
        ret = cli.datamodule.transforms.val.__uncall__(ret)


        cvtb = lambda f, mf : einops.rearrange(f.numpy(), ' 1 k i j -> i j k')*mf

        return cvtb(ret['SgsU'], mask_u) , cvtb(ret['SgsV'], mask_v)


if __name__ == '__main__' :

    b, c, i, j = 1, 2, 100, 200
    def function_mat_python(b, c, i, j) :
        return b*0.7 + c*0.1 + i*0.827 + j*0.193

    def create_mat_python(b, c, i, j) :
        inp = torch.zeros((b,c, i ,j))
        for bi in range(0,b):
            for ci in range(0,c) :
                for ii in range(0,i):
                    for ji in range(0,j) :
                        inp[bi, ci, ii, ji] = function_mat_python(bi,ci,ii,ji)
        return inp

    inp = create_mat_python(b,c,i,j)

    u = inp[:,0].permute(1,2,0).numpy()
    v = inp[:,1].permute(1,2,0).numpy()
    mask_u = np.ones_like(u).astype('float32')
    mask_v = np.ones_like(v).astype('float32')

    n_u, n_v = momentum_cnn(u, v, mask_u, mask_v, sampling=False)
    print(f'Returned n_u : {n_u.shape} n_v : {n_v.shape}')
    print('Max diff n_u', np.max(np.abs(n_u - n_u)),'- max diff n_v', np.max(np.abs(n_v - n_v)))
    print(f'Test successful')
