module test_gmc_hybrid
  use testdrive,only:new_unittest,unittest_type,error_type,check,test_failed
  use crest_parameters
  use crest_calculator
  use crest_data,only:refine
  use parse_hybrid,only:parse_hybrid_argument
  use strucrd
  use crest_testmol,only:get_testmol
  use cregen_subroutines,only:cregen_esort
  implicit none
  private

  public :: collect_gmc_hybrid

  real(wp),parameter :: tol = 1.0e-9_wp

contains

  subroutine collect_gmc_hybrid(testsuite)
    type(unittest_type),allocatable,intent(out) :: testsuite(:)
    testsuite = [ &
      new_unittest("H1 hybrid parser semantics         ",test_parser), &
      new_unittest("H2 workhorse raw energy           ",test_workhorse_raw), &
      new_unittest("H3 quality SP raw energy           ",test_quality_sp_raw), &
      new_unittest("H4 workhorse restraint decomposition",test_workhorse_restraint), &
      new_unittest("H5 quality restraint decomposition ",test_quality_restraint), &
      new_unittest("P1 plain XYZ persistence CREGEN    ",test_plain_persistence), &
      new_unittest("P2 extxyz persistence CREGEN      ",test_extxyz_persistence), &
      new_unittest("P3 legacy persistence CREGEN      ",test_legacy_persistence) &
    ]
  end subroutine collect_gmc_hybrid

  subroutine make_single(calc,method)
    type(calcdata),intent(out) :: calc
    character(len=*),intent(in) :: method
    type(calculation_settings) :: sett
    call sett%create(trim(method))
    call sett%autocomplete(1)
    call calc%add(sett)
  end subroutine make_single

  subroutine make_hybrid(calc)
    type(calcdata),intent(out) :: calc
    type(calculation_settings) :: workhorse,quality
    call workhorse%create('gfnff')
    workhorse%refine_lvl = refine%non
    call workhorse%autocomplete(1)
    call calc%add(workhorse)
    call quality%create('gfn2')
    quality%refine_lvl = refine%singlepoint
    call quality%autocomplete(2)
    call calc%add(quality)
  end subroutine make_hybrid

  subroutine evaluate(mol,calc,energy,io)
    type(coord),intent(inout) :: mol
    type(calcdata),intent(inout) :: calc
    real(wp),intent(out) :: energy
    integer,intent(out) :: io
    real(wp),allocatable :: gradient(:,:)
    allocate (gradient(3,mol%nat),source=0.0_wp)
    call engrad(mol,calc,energy,gradient,io)
    deallocate (gradient)
  end subroutine evaluate

  subroutine check_parse(error,text,expected_quality,expected_workhorse,expected_mode)
    type(error_type),allocatable,intent(inout) :: error
    character(len=*),intent(in) :: text,expected_quality,expected_workhorse
    character(len=*),intent(in) :: expected_mode
    character(len=:),allocatable :: quality,workhorse
    character(len=4) :: mode
    integer :: io
    if (allocated(error)) return
    call parse_hybrid_argument(text,quality,workhorse,mode,io)
    call check(error,io,0)
    if (allocated(error)) return
    if (trim(quality) /= trim(expected_quality)) then
      call test_failed(error,'wrong quality method for '//trim(text))
      return
    end if
    if (trim(workhorse) /= trim(expected_workhorse)) then
      call test_failed(error,'wrong workhorse method for '//trim(text))
      return
    end if
    if (trim(mode) /= trim(expected_mode)) then
      call test_failed(error,'wrong hybrid mode for '//trim(text))
    end if
  end subroutine check_parse

  subroutine test_parser(error)
    type(error_type),allocatable,intent(out) :: error
    call check_parse(error,'gfn2@gfnff','gfn2','gfnff','at')
    if (allocated(error)) return
    call check_parse(error,'gfn2//gfnff','gfn2','gfnff','sp')
    if (allocated(error)) return
    call check_parse(error,'gfn2/opt/gfnff','gfn2','gfnff','opt')
  end subroutine test_parser

  subroutine assert_valid_components(error,mol,raw,restraint,total)
    type(error_type),allocatable,intent(inout) :: error
    type(coord),intent(in) :: mol
    real(wp),intent(in) :: raw,restraint,total
    if (allocated(error)) return
    if (.not.mol%energy_components_valid) then
      call test_failed(error,'energy components are invalid')
      return
    end if
    call check(error,mol%energy_raw,raw,thr=tol)
    if (allocated(error)) return
    call check(error,mol%energy_restraint,restraint,thr=tol)
    if (allocated(error)) return
    call check(error,mol%energy_total,total,thr=tol)
    if (allocated(error)) return
    call check(error,mol%energy,total,thr=tol)
    if (allocated(error)) return
    if (abs(mol%energy_total-mol%energy_raw-mol%energy_restraint) > tol) then
      call test_failed(error,'energy component identity is violated')
    end if
  end subroutine assert_valid_components

  subroutine add_test_restraint(calc,mol,delta,force_constant)
    type(calcdata),intent(inout) :: calc
    type(coord),intent(in) :: mol
    real(wp),intent(in) :: delta,force_constant
    type(constraint) :: constr
    call constr%bondconstraint(1,2,mol%dist(1,2)+delta,force_constant)
    call calc%add(constr)
  end subroutine add_test_restraint

  subroutine test_workhorse_raw(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: hybrid,reference
    type(coord) :: hybrid_mol,reference_mol
    real(wp) :: expected,actual
    integer :: io
    call make_hybrid(hybrid)
    call make_single(reference,'gfnff')
    call get_testmol('methane',hybrid_mol)
    reference_mol = hybrid_mol
    call evaluate(reference_mol,reference,expected,io)
    call check(error,io,0)
    if (allocated(error)) return
    call evaluate(hybrid_mol,hybrid,actual,io)
    call check(error,io,0)
    if (allocated(error)) return
    call assert_valid_components(error,hybrid_mol,expected,0.0_wp,expected)
    if (allocated(error)) return
    call check(error,actual,expected,thr=tol)
  end subroutine test_workhorse_raw

  subroutine test_quality_sp_raw(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: hybrid,reference
    type(coord) :: hybrid_mol,reference_mol
    real(wp) :: expected,actual
    integer :: io
    call make_hybrid(hybrid)
    call make_single(reference,'gfn2')
    call get_testmol('methane',hybrid_mol)
    reference_mol = hybrid_mol
    call evaluate(reference_mol,reference,expected,io)
    call check(error,io,0)
    if (allocated(error)) return
    hybrid%refine_stage = refine%singlepoint
    call evaluate(hybrid_mol,hybrid,actual,io)
    call check(error,io,0)
    if (allocated(error)) return
    call assert_valid_components(error,hybrid_mol,expected,0.0_wp,expected)
    if (allocated(error)) return
    call check(error,actual,expected,thr=tol)
  end subroutine test_quality_sp_raw

  subroutine test_workhorse_restraint(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: hybrid,reference
    type(coord) :: hybrid_mol,reference_mol
    real(wp) :: expected,restraint_energy,actual
    integer :: io
    call make_hybrid(hybrid)
    call make_single(reference,'gfnff')
    call get_testmol('methane',hybrid_mol)
    reference_mol = hybrid_mol
    call add_test_restraint(hybrid,hybrid_mol,0.20_wp,1.0_wp)
    call evaluate(reference_mol,reference,expected,io)
    call check(error,io,0)
    if (allocated(error)) return
    call evaluate(hybrid_mol,hybrid,actual,io)
    call check(error,io,0)
    if (allocated(error)) return
    restraint_energy = hybrid_mol%energy_restraint
    call assert_valid_components(error,hybrid_mol,expected,restraint_energy,actual)
    if (allocated(error)) return
    if (restraint_energy <= 0.0_wp) call test_failed(error,'workhorse restraint is not positive')
  end subroutine test_workhorse_restraint

  subroutine test_quality_restraint(error)
    type(error_type),allocatable,intent(out) :: error
    type(calcdata) :: hybrid,reference
    type(coord) :: hybrid_mol,reference_mol
    real(wp) :: expected,restraint_energy,actual
    integer :: io
    call make_hybrid(hybrid)
    call make_single(reference,'gfn2')
    call get_testmol('methane',hybrid_mol)
    reference_mol = hybrid_mol
    call add_test_restraint(hybrid,hybrid_mol,0.20_wp,1.0_wp)
    call evaluate(reference_mol,reference,expected,io)
    call check(error,io,0)
    if (allocated(error)) return
    hybrid%refine_stage = refine%singlepoint
    call evaluate(hybrid_mol,hybrid,actual,io)
    call check(error,io,0)
    if (allocated(error)) return
    restraint_energy = hybrid_mol%energy_restraint
    call assert_valid_components(error,hybrid_mol,expected,restraint_energy,actual)
    if (allocated(error)) return
    if (restraint_energy <= 0.0_wp) call test_failed(error,'quality restraint is not positive')
  end subroutine test_quality_restraint

  subroutine make_persistence_pair(structures,valid,extxyz)
    type(coord),allocatable,intent(out) :: structures(:)
    logical,intent(in) :: valid,extxyz
    allocate (structures(2))
    call get_testmol('methane',structures(1))
    call get_testmol('methane',structures(2))
    if (valid) then
      call structures(1)%set_energy_components(-10.000_wp,0.010_wp,-9.990_wp)
      call structures(2)%set_energy_components(-9.995_wp,-0.004_wp,-9.999_wp)
    else
      structures(1)%energy = -10.000_wp
      structures(2)%energy = -9.995_wp
      call structures(1)%invalidate_energy_components()
      call structures(2)%invalidate_energy_components()
    end if
    structures(:)%wrextxyz = extxyz
  end subroutine make_persistence_pair

  subroutine assert_persisted(error,structures,valid)
    type(error_type),allocatable,intent(inout) :: error
    type(coord),intent(in) :: structures(:)
    logical,intent(in) :: valid
    if (allocated(error)) return
    if (size(structures) < 1) then
      call test_failed(error,'empty ensemble after persistence roundtrip')
      return
    end if
    if (valid) then
      call assert_valid_components(error,structures(1),-10.000_wp,0.010_wp,-9.990_wp)
    else
      if (structures(1)%energy_components_valid) then
        call test_failed(error,'legacy ensemble acquired valid components')
        return
      end if
      call check(error,structures(1)%ranking_energy(),structures(1)%energy,thr=tol)
      call check(error,structures(1)%energy,-10.000_wp,thr=tol)
    end if
  end subroutine assert_persisted

  subroutine run_component_persistence(error,fname,extxyz)
    type(error_type),allocatable,intent(inout) :: error
    character(len=*),intent(in) :: fname
    logical,intent(in) :: extxyz
    type(coord),allocatable :: source(:),loaded(:),reread(:)
    integer :: nall,nout
    character(len=256) :: sorted_name
    sorted_name = trim(fname)//'.sorted'
    call make_persistence_pair(source,.true.,extxyz)
    call wrensemble(trim(fname),size(source),source)
    call rdensemble(trim(fname),nall,loaded)
    call check(error,nall,2)
    if (allocated(error)) then
      call remove_file(trim(fname))
      return
    end if
    call assert_persisted(error,loaded,.true.)
    if (allocated(error)) then
      call remove_file(trim(fname))
      return
    end if
    call cregen_esort(stdout,loaded,nout)
    call check(error,nout,2)
    if (allocated(error)) then
      call remove_file(trim(fname))
      return
    end if
    call wrensemble(trim(sorted_name),nout,loaded)
    call rdensemble(trim(sorted_name),nall,reread)
    call check(error,nall,2)
    if (allocated(error)) then
      call remove_file(trim(fname))
      call remove_file(trim(sorted_name))
      return
    end if
    call assert_persisted(error,reread,.true.)
    call remove_file(trim(fname))
    call remove_file(trim(sorted_name))
  end subroutine run_component_persistence

  subroutine test_plain_persistence(error)
    type(error_type),allocatable,intent(out) :: error
    call run_component_persistence(error,'gmc_hybrid_plain.xyz',.false.)
  end subroutine test_plain_persistence

  subroutine test_extxyz_persistence(error)
    type(error_type),allocatable,intent(out) :: error
    call run_component_persistence(error,'gmc_hybrid_extxyz.extxyz',.true.)
  end subroutine test_extxyz_persistence

  subroutine test_legacy_persistence(error)
    type(error_type),allocatable,intent(out) :: error
    type(coord),allocatable :: source(:),loaded(:),reread(:)
    integer :: nall,nout
    character(len=*),parameter :: fname = 'gmc_hybrid_legacy.xyz'
    character(len=*),parameter :: sorted_name = 'gmc_hybrid_legacy.xyz.sorted'
    call make_persistence_pair(source,.false.,.false.)
    call wrensemble(fname,size(source),source)
    call rdensemble(fname,nall,loaded)
    call check(error,nall,2)
    if (allocated(error)) then
      call remove_file(fname)
      return
    end if
    call cregen_esort(stdout,loaded,nout)
    call check(error,nout,2)
    if (allocated(error)) then
      call remove_file(fname)
      return
    end if
    call wrensemble(sorted_name,nout,loaded)
    call rdensemble(sorted_name,nall,reread)
    call check(error,nall,2)
    if (allocated(error)) then
      call remove_file(fname)
      call remove_file(sorted_name)
      return
    end if
    call assert_persisted(error,reread,.false.)
    call remove_file(fname)
    call remove_file(sorted_name)
  end subroutine test_legacy_persistence

  subroutine remove_file(fname)
    character(len=*),intent(in) :: fname
    logical :: exists
    integer :: iunit,io
    inquire (file=trim(fname),exist=exists)
    if (exists) then
      open (newunit=iunit,file=trim(fname),status='old',iostat=io)
      if (io == 0) close (iunit,status='delete')
    end if
  end subroutine remove_file

end module test_gmc_hybrid
