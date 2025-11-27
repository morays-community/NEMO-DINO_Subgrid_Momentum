# eophis API
import eophis
from eophis import Freqs
# other modules
import argparse
import os

def ocean_info():
    # ocean namelist
    nemo_nml = eophis.FortranNamelist(os.path.join(os.getcwd(),'namelist_cfg'))
    step,  = nemo_nml.get('rn_Dt')
    nlvl = 36

    # coupling config
    tunnel_config = list()
    tunnel_config.append( { 'label' : 'TO_NEMO_FIELDS', \
                            'grids' : { 'DINO_Grid' : {'npts' : (62,199), 'halos' : 7, 'bnd' : ('close','close') }  }, \
                            'exchs' : [ {'freq' : step, 'grd' : 'DINO_Grid', 'lvl' : nlvl, 'in' : ['u','v'], 'out' : ['u_f','v_f']} ] }
                        )
                        
    # static coupling (manual send/receive)
    tunnel_config.append( { 'label' : 'TO_NEMO_METRICS', \
                            'grids' : { 'DINO_Grid' : {'npts' : (62,199), 'halos' : 7, 'bnd' : ('close','close') }  }, \
                            'exchs' : [ {'freq' : Freqs.STATIC, 'grd' : 'DINO_Grid', 'lvl' : nlvl, 'in' : ['mask_u','mask_v'], 'out' : []} ] }
                        )
                        
    return tunnel_config, nemo_nml


def preproduction():
    eophis.info('========= MORAYS : Pre-Production =========')
    eophis.info('  Aim: write coupling namelist\n')

    # ocean info
    tunnel_config, nemo_nml = ocean_info()
    step, it_end, it_0 = nemo_nml.get('rn_Dt','nn_itend','nn_it000')
    total_time = (it_end - it_0 + 1) * step

    # tunnel registration (lazy) compulsory to update namelist
    eophis.register_tunnels( tunnel_config )
    
    # write updated namelist
    eophis.write_coupling_namelist( simulation_time=total_time )


def production():
    eophis.info('========= MORAYS : Production =========')
    eophis.info('  Aim: execute coupled simulation\n')

    #  Ocean Coupling
    # ++++++++++++++++
    tunnel_config, nemo_nml = ocean_info()
    step, it_end, it_0 = nemo_nml.get('rn_Dt','nn_itend','nn_it000')
    niter = it_end - it_0 + 1
    total_time = niter * step

    # tunnel registration (lazy)
    nemo, nemo_metrics = eophis.register_tunnels( tunnel_config )

    # link all tunnels (beware, dormant errors will likely appear here)
    eophis.open_tunnels()

    #  Models
    # ++++++++
    from ml_models import momentum_cnn

    # get masks
    mask_u = nemo_metrics.receive('mask_u')
    mask_v = nemo_metrics.receive('mask_v')

    #  Assemble
    # ++++++++++
    @eophis.all_in_all_out(geo_model=nemo, step=step, niter=niter)
    def loop_core(**inputs):
        outputs = {}
        outputs['u_f'], outputs['v_f'] = momentum_cnn( u=inputs['u'], v=inputs['v'], mask_u=mask_u, mask_v=mask_v )
        return outputs

    #  Run
    # +++++
    eophis.starter(loop_core)
    
# ============================ #
if __name__=='__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument('--exec', dest='exec', type=str, default='prod', help='Execution type: preprod or prod')
    args = parser.parse_args()

    eophis.set_mode(args.exec)

    if args.exec == 'preprod':
        preproduction()
    elif args.exec == 'prod':
        production()
    else:
        eophis.abort(f'Unknown execution mode {args.exec}, use "preprod" or "prod"')
