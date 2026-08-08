module test_gmc_cregen
  use testdrive,only:new_unittest,unittest_type,error_type,check,test_failed
  use crest_parameters
  use crest_data,only:systemdata
  use strucrd
  use crest_testmol,only:get_testmol
  use cregen_interface,only:newcregen
  use cregen_subroutines,only:cregen_esort,cregen_CRE_new,cregen_CRE_periodic
  implicit none
  private

  public :: collect_gmc_cregen

  real(wp),parameter :: tol = 1.0e-10_wp
  real(wp),parameter :: ewin_kcal = 4.0_wp
  real(wp),parameter :: ethr_mol = 0.007_wp
  real(wp),parameter :: ethr_periodic = 0.007_wp

contains

  subroutine collect_gmc_cregen(testsuite)
    type(unittest_type),allocatable,intent(out) :: testsuite(:)
    testsuite = [ &
      new_unittest("C1 raw/total ranking inversion  ",test_raw_sort), &
      new_unittest("C2 raw EWIN both directions    ",test_raw_ewin), &
      new_unittest("C3 molecular ETHR uses raw     ",test_molecular_ethr), &
      new_unittest("C4 representative is raw-first ",test_raw_representative), &
      new_unittest("C5 legacy/constraint-off equal ",test_legacy_constraint_off), &
      new_unittest("C6 periodic ETHR uses raw      ",test_periodic_ethr), &
      new_unittest("C7 new CREGEN elowest is raw   ",test_newcregen_elowest) &
    ]
  end subroutine collect_gmc_cregen

  subroutine make_structure(mol,tag,raw,total,valid)
    type(coord),intent(out) :: mol
    character(len=*),intent(in) :: tag
    real(wp),intent(in) :: raw,total
    logical,intent(in) :: valid
    call get_testmol('methane',mol)
    mol%origin = tag
    mol%energy = total
    if (valid) then
      call mol%set_energy_components(raw,total-raw,total)
    else
      call mol%invalidate_energy_components()
    end if
  end subroutine make_structure

  subroutine make_pair(ensemble,raw_a,total_a,raw_b,total_b)
    type(coord),allocatable,intent(out) :: ensemble(:)
    real(wp),intent(in) :: raw_a,total_a,raw_b,total_b
    allocate (ensemble(2))
    call make_structure(ensemble(1),'A',raw_a,total_a,.true.)
    call make_structure(ensemble(2),'B',raw_b,total_b,.true.)
  end subroutine make_pair

  subroutine check_first(error,ensemble,expected)
    type(error_type),allocatable,intent(inout) :: error
    type(coord),intent(in) :: ensemble(:)
    character(len=*),intent(in) :: expected
    if (allocated(error)) return
    if (.not.allocated(ensemble(1)%origin)) then
      call test_failed(error,'sorted structure has no identity: expected '//trim(expected))
    else if (trim(ensemble(1)%origin) /= trim(expected)) then
      call test_failed(error,'wrong first structure: expected '//trim(expected)// &
        & ', got '//trim(ensemble(1)%origin))
    end if
  end subroutine check_first

  subroutine test_raw_sort(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord),allocatable :: ensemble(:)
    integer :: nout
    call make_pair(ensemble,-10.000_wp,-9.990_wp,-9.995_wp,-9.999_wp)
    call cregen_esort(stdout,ensemble,nout)
    call check_first(error,ensemble,'A')
    if (allocated(error)) return
    call check(error,nout,2)
    call check(error,ensemble(1)%ranking_energy(),-10.000_wp,thr=tol)
  end subroutine test_raw_sort

  subroutine test_raw_ewin(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord),allocatable :: ensemble(:)
    integer :: nout
    call make_pair(ensemble,-10.000_wp,-9.990_wp,-9.995_wp,-9.999_wp)
    call cregen_esort(stdout,ensemble,nout,ewin=ewin_kcal)
    call check(error,nout,2)
    if (allocated(error)) return
    call check_first(error,ensemble,'A')
    if (allocated(error)) return
    deallocate (ensemble)
    call make_pair(ensemble,-10.000_wp,-9.999_wp,-9.990_wp,-10.000_wp)
    call cregen_esort(stdout,ensemble,nout,ewin=ewin_kcal)
    call check(error,nout,1)
    if (allocated(error)) return
    call check_first(error,ensemble,'A')
  end subroutine test_raw_ewin

  subroutine setup_cregen_env(env,nat)
    type(systemdata),intent(out) :: env
    integer,intent(in) :: nat
    env%rednat = nat
    env%subRMSD = .false.
    env%heavyrmsd = .false.
    env%ENSO = .false.
    env%confgo = .false.
    env%QCG = .false.
    env%entropic = .false.
    env%doNMR = .false.
    env%checktopo = .false.
    env%checkiso = .false.
    env%relax = .false.
    env%properties = 0
    env%crestver = 0
    env%cgf = .false.
    env%tboltz = 298.15_wp
    env%rthr = 0.1_wp
    env%ethr = ethr_mol*autokcal
    env%bthr = 0.025_wp
    env%ewin = ewin_kcal
    env%athr = 0.1_wp
    env%pthr = 0.05_wp
  end subroutine setup_cregen_env

  subroutine test_molecular_ethr(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord),allocatable :: ensemble(:)
    type(systemdata) :: env
    integer,allocatable :: groups(:)
    integer :: nout
    call make_pair(ensemble,-10.000_wp,-9.990_wp,-9.995_wp,-9.999_wp)
    call cregen_esort(stdout,ensemble,nout)
    call setup_cregen_env(env,ensemble(1)%nat)
    call cregen_CRE_new(env,nout,ensemble,groups,0.1_wp,ethr_mol,0.025_wp, &
      &                  printlvl=0,ch=stdout)
    call check(error,nout,1)
    if (allocated(error)) return
    call check_first(error,ensemble,'A')
  end subroutine test_molecular_ethr

  subroutine test_raw_representative(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord),allocatable :: ensemble(:)
    type(systemdata) :: env
    integer,allocatable :: groups(:)
    integer :: nout
    call make_pair(ensemble,-10.000_wp,-9.990_wp,-9.995_wp,-9.999_wp)
    call cregen_esort(stdout,ensemble,nout)
    call setup_cregen_env(env,ensemble(1)%nat)
    call cregen_CRE_new(env,nout,ensemble,groups,0.1_wp,0.010_wp,0.025_wp, &
      &                  printlvl=0,ch=stdout)
    call check(error,nout,1)
    if (allocated(error)) return
    call check_first(error,ensemble,'A')
  end subroutine test_raw_representative

  subroutine test_legacy_constraint_off(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord),allocatable :: legacy(:),off(:)
    type(systemdata) :: env
    integer,allocatable :: groups(:)
    integer :: nlegacy,noff
    allocate (legacy(3),off(3))
    call make_structure(legacy(1),'A',-10.000_wp,-10.000_wp,.false.)
    call make_structure(legacy(2),'B',-9.995_wp,-9.995_wp,.false.)
    call make_structure(legacy(3),'C',-9.990_wp,-9.990_wp,.false.)
    call make_structure(off(1),'A',-10.000_wp,-10.000_wp,.true.)
    call make_structure(off(2),'B',-9.995_wp,-9.995_wp,.true.)
    call make_structure(off(3),'C',-9.990_wp,-9.990_wp,.true.)
    call cregen_esort(stdout,legacy,nlegacy,ewin=ewin_kcal)
    call cregen_esort(stdout,off,noff,ewin=ewin_kcal)
    call check(error,nlegacy,noff)
    if (allocated(error)) return
    call check(error,nlegacy,2)
    if (allocated(error)) return
    call check_first(error,legacy,'A')
    if (allocated(error)) return
    call check_first(error,off,'A')
    if (allocated(error)) return
    call check(error,trim(legacy(2)%origin),trim(off(2)%origin))
    if (allocated(error)) return
    call setup_cregen_env(env,legacy(1)%nat)
    call cregen_CRE_new(env,nlegacy,legacy,groups,0.1_wp,0.007_wp,0.025_wp, &
      &                  printlvl=0,ch=stdout)
    call check(error,nlegacy,1)
    if (allocated(error)) return
    call setup_cregen_env(env,off(1)%nat)
    call cregen_CRE_new(env,noff,off,groups,0.1_wp,0.007_wp,0.025_wp, &
      &                  printlvl=0,ch=stdout)
    call check(error,noff,1)
    if (allocated(error)) return
    call check_first(error,legacy,'A')
    if (allocated(error)) return
    call check_first(error,off,'A')
  end subroutine test_legacy_constraint_off

  subroutine add_periodic_cell(mol)
    type(coord),intent(inout) :: mol
    if (allocated(mol%lat)) deallocate (mol%lat)
    allocate (mol%lat(3,3),source=0.0_wp)
    mol%lat(1,1) = 50.0_wp
    mol%lat(2,2) = 50.0_wp
    mol%lat(3,3) = 50.0_wp
  end subroutine add_periodic_cell

  subroutine test_periodic_ethr(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord),allocatable :: ensemble(:)
    type(systemdata) :: env
    integer,allocatable :: groups(:)
    integer :: nout
    call make_pair(ensemble,-10.000_wp,-9.990_wp,-9.995_wp,-9.999_wp)
    call add_periodic_cell(ensemble(1))
    call add_periodic_cell(ensemble(2))
    call cregen_esort(stdout,ensemble,nout)
    call setup_cregen_env(env,ensemble(1)%nat)
    call cregen_CRE_periodic(env,nout,ensemble,groups,0.1_wp,ethr_periodic, &
      &                       printlvl=0,ch=stdout)
    call check(error,nout,1)
    if (allocated(error)) return
    call check_first(error,ensemble,'A')
  end subroutine test_periodic_ethr

  subroutine test_newcregen_elowest(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord),allocatable :: ensemble(:)
    type(systemdata) :: env
    call make_pair(ensemble,-10.000_wp,-9.990_wp,-9.995_wp,-9.999_wp)
    call setup_cregen_env(env,ensemble(1)%nat)
    env%ensemblename = 'gmc_cregen_synthetic.xyz'
    allocate (env%calc)
    call env%ref%load(ensemble(1))
    call newcregen(env,structurelist=ensemble)
    deallocate (env%calc)
    call check(error,env%elowest,-10.000_wp,thr=tol)
    if (allocated(error)) then
      call cleanup_outputs()
      return
    end if
    call check_first(error,ensemble,'A')
    call cleanup_outputs()
  end subroutine test_newcregen_elowest

  subroutine cleanup_outputs()
    call remove_file('gmc_cregen_synthetic.xyz.sorted')
    call remove_file('crest_ensemble.xyz')
    call remove_file('crest_best.xyz')
    call remove_file('crest.energies')
    call remove_file('cregen.out.tmp')
    call remove_file('cregen.full')
    call remove_file('cre_members')
  end subroutine cleanup_outputs

  subroutine remove_file(fname)
    character(len=*),intent(in) :: fname
    logical :: exists
    integer :: iunit,io
    inquire (file=fname,exist=exists)
    if (exists) then
      open (newunit=iunit,file=fname,status='old',iostat=io)
      if (io == 0) close (iunit,status='delete')
    end if
  end subroutine remove_file

end module test_gmc_cregen
