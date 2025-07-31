import numpy as np
from numpy.matrixlib import bmat
import torch, einops
import sys
sys.path.append('ZB-DINO')

from models.LitParamModel import LitParamModel
from csvflowdatamodule.CsvDataModule import CsvDataModule
from scipy import stats


from lightning.pytorch.cli import LightningCLI

path_par_model ='ZB-DINO/config/model/simple2D.yaml'
path_par_data ='ZB-DINO/config/data/subgrid_V1.yaml'
path_model = 'ZB-DINO/weights/9fxvecvn/checkpoints/last.ckpt'

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
def momentum_cnn(u, v, mask_u, mask_v):
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
        global cli, device

        batch = {}

        cvt = lambda f, mf : torch.tensor(einops.rearrange(f.astype(np.float32)*mf.astype(np.float32), 'i j k -> 1 k i j')).to(device)
        batch['CoarsedU'] = cvt(u, mask_u)
        batch['CoarsedV'] = cvt(v, mask_v)

        batch = cli.datamodule.transforms.val.__call__(batch)
        # preds
        ret = cli.model(batch)

        # renormalize
        ret = cli.datamodule.transforms.val.__uncall__(ret)


        cvtb = lambda f, mf : einops.rearrange(f.nan_to_num(0.0).numpy(), ' 1 k i j -> i j k')*mf

        return cvtb(ret['SgsU'], mask_u), cvtb(ret['SgsV'], mask_v)


if __name__ == '__main__' :

    k, i, j = 36, 100, 200
    u = np.random.randn(i, j, k)
    v = np.random.randn(i, j, k)
    mask_u = np.ones((i, j, 1))
    mask_v = np.ones((i, j, 1))

    sgs_u, sgs_v = momentum_cnn(u, v, mask_u, mask_v)
    print('SgsU shape :', sgs_u.shape)
    print('SgsU describe :', stats.describe(sgs_u.flatten()))

    print(f'Test successful')
