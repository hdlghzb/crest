!================================================================================!
! This file is part of crest.
!
! Copyright (C) 2023-2025 Philipp Pracht
!
! crest is free software: you can redistribute it and/or modify it under
! the terms of the GNU Lesser General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! crest is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU Lesser General Public License for more details.
!
! You should have received a copy of the GNU Lesser General Public License
! along with crest.  If not, see <https://www.gnu.org/licenses/>.
!================================================================================!

!> This is the fallback reader for xtb input files.
!> Defining constrains in this format is a bit easier than with toml
!> Furthermore, it should provide some higher degree of compatibility
!> between CREST and xTB.
!> The xtb-style keywords in CREST are limited to geometrical constraints
!> These are files that can be read with the --cinp option

module parse_xtbinput
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use crest_parameters
  use crest_data
  use crest_calculator,only:calcdata
  use parse_datastruct
  use parse_keyvalue
  use parse_block
  use parse_datastruct
  use filemod
  use iomod
  use strucrd
  use wall_setup
  use constraints,only:constraint
  implicit none
  private
  !logical,parameter,private :: debug = .true.
  logical,parameter,private :: debug = .false.

  public :: parse_xtbinputfile
  interface parse_xtbinputfile
    module procedure :: parse_xtb_inputfile
    module procedure :: parse_xtb_input_fallback
  end interface parse_xtbinputfile

  public :: parse_constraints_from_cts
  public :: parse_qcg_final_constraints

!========================================================================================!
!========================================================================================!
contains  !> MODULE PROCEDURES START HERE
!========================================================================================!
!========================================================================================!

  subroutine parse_xtb_inputfile(env,fname)
!*********************************************
!* Routine for parsing the input file fname
!* and storing information in env
!*********************************************
    implicit none
    type(systemdata),intent(inout) :: env
    character(len=*),intent(in)    :: fname

    type(root_object),allocatable,target :: dict
    type(datablock),pointer :: blk
    logical :: ex
    character(len=:),allocatable :: hdr
    integer :: i,j,k,l
    type(coord) :: mol

    inquire (file=fname,exist=ex)
    if (.not.ex) return

    allocate (dict)
    call parse_xtb_input_fallback(fname,dict)
    !call dict%print()

    !> get the ref structure
    call env%ref%to(mol)

    write (stdout,'(a,a,a)') 'Parsing xtb-type input file ',trim(fname), &
    & ' to set up calculators ...'
    !> iterate through the blocks and save the necessary information
    do i = 1,dict%nblk
      blk => dict%blk_list(i)
      hdr = trim(blk%header)
      select case (hdr)
      case ('constrain')
        call get_xtb_constraint_block(env%calc,mol,blk)
      case ('wall')
        call get_xtb_wall_block(env%calc,mol,env%potscal,blk)
      case ('fix')
        call get_xtb_fix_block(env%calc,mol,blk)
      case ('metadyn')
        call get_xtb_metadyn_block(env%calc,mol,env%mtd_kscal, &
        & env%includeRMSD,env%rednat,blk)
      case default
        write (stdout,'(a,a,a)') 'xtb-style input block: "$',trim(hdr),'" not defined for CREST'
      end select
    end do

    if (debug) stop
  end subroutine parse_xtb_inputfile

!========================================================================================!

  subroutine parse_qcg_final_constraints(calc,mol,fname,soluatoms,iostatus)
!> Strict final-only reader: one $constrain block and numeric internal coordinates only.
    implicit none
    type(calcdata),intent(inout) :: calc
    type(coord),intent(in) :: mol
    character(len=*),intent(in) :: fname
    integer,intent(in) :: soluatoms
    integer,intent(out) :: iostatus

    type(datablock) :: block
    type(keyvalue) :: kv
    character(len=1024) :: rawline
    character(len=:),allocatable :: line,header
    logical :: ex,in_block,saw_block,force_seen
    integer :: unit,io,line_no,j,ntarget
    real(wp) :: force_constant

    iostatus = 1
    if (allocated(calc%cons)) deallocate (calc%cons)
    calc%nconstraints = 0
    force_constant = 0.05_wp
    force_seen = .false.
    in_block = .false.
    saw_block = .false.
    ntarget = 0
    line_no = 0
    call block%deallocate()
    block%header = 'constrain'

    inquire (file=trim(fname),exist=ex)
    if (.not.ex) then
      call qcg_final_constraint_error(fname,0,'file not found')
      call block%deallocate()
      return
    end if
    open (newunit=unit,file=trim(fname),status='old',action='read',iostat=io)
    if (io /= 0) then
      call qcg_final_constraint_error(fname,0,'file could not be opened')
      call block%deallocate()
      return
    end if

    do
      read (unit,'(a)',iostat=io) rawline
      if (io < 0) exit
      line_no = line_no+1
      if (io /= 0) then
        close (unit)
        call block%deallocate()
        call qcg_final_constraint_error(fname,line_no,'read error')
        return
      end if
      line = trim(adjustl(rawline))
      j = index(line,'#')
      if (j == 1) cycle
      if (j > 1) line = trim(line(:j-1))
      if (len_trim(line) == 0) cycle

      if (line(1:1) == '$') then
        header = lowercase(trim(line))
        if (header == '$constrain') then
          if (saw_block .or. in_block) then
            close (unit)
            call block%deallocate()
            call qcg_final_constraint_error(fname,line_no,'multiple $constrain blocks')
            return
          end if
          in_block = .true.
          saw_block = .true.
        else if (header == '$end') then
          if (.not.in_block) then
            close (unit)
            call block%deallocate()
            call qcg_final_constraint_error(fname,line_no,'unexpected $end')
            return
          end if
          in_block = .false.
        else
          close (unit)
          call block%deallocate()
          call qcg_final_constraint_error(fname,line_no,'unsupported block '//trim(header))
          return
        end if
        cycle
      end if

      if (.not.in_block) then
        close (unit)
        call block%deallocate()
        call qcg_final_constraint_error(fname,line_no,'content outside $constrain')
        return
      end if
      call get_xtb_keyvalue(kv,line,io)
      if (io /= 0) then
        close (unit)
        call block%deallocate()
        call qcg_final_constraint_error(fname,line_no,'malformed key/value line')
        return
      end if
      select case (kv%key)
      case ('force constant')
        if (force_seen) then
          close (unit)
          call block%deallocate()
          call qcg_final_constraint_error(fname,line_no,'duplicate force constant')
          return
        end if
        if (.not.qcg_final_real_token(kv%rawvalue,force_constant)) then
          close (unit)
          call block%deallocate()
          call qcg_final_constraint_error(fname,line_no,'force constant must be numeric')
          return
        end if
        force_seen = .true.
      case ('distance','bond','angle','dihedral')
        ntarget = ntarget+1
      case default
        close (unit)
        call block%deallocate()
        call qcg_final_constraint_error(fname,line_no,'unsupported key '//trim(kv%key))
        return
      end select
      call block%addkv(kv)
    end do
    close (unit)

    if (.not.saw_block .or. in_block .or. ntarget == 0) then
      call block%deallocate()
      call qcg_final_constraint_error(fname,line_no,'requires a closed $constrain block with constraints')
      return
    end if
    call build_qcg_final_constraints(calc,mol,block,soluatoms,force_constant,trim(fname),iostatus)
    call block%deallocate()
    if (iostatus /= 0) then
      if (allocated(calc%cons)) deallocate (calc%cons)
      calc%nconstraints = 0
    end if
  end subroutine parse_qcg_final_constraints

!========================================================================================!

  subroutine qcg_final_constraint_error(fname,line_no,message)
    implicit none
    character(len=*),intent(in) :: fname,message
    integer,intent(in) :: line_no
    if (line_no > 0) then
      write (stdout,'(1x,a,i0,2a)') 'QCG final constraint error in line ',line_no, &
      & ' of ',trim(fname)//': '//trim(message)
    else
      write (stdout,'(1x,3a)') 'QCG final constraint error in ',trim(fname),': '//trim(message)
    end if
  end subroutine qcg_final_constraint_error

!========================================================================================!

  subroutine build_qcg_final_constraints(calc,mol,block,soluatoms,force_constant,fname,iostatus)
    implicit none
    type(calcdata),intent(inout) :: calc
    type(coord),intent(in) :: mol
    type(datablock),intent(in) :: block
    integer,intent(in) :: soluatoms
    real(wp),intent(in) :: force_constant
    character(len=*),intent(in) :: fname
    integer,intent(out) :: iostatus
    type(keyvalue) :: kv
    type(constraint) :: cons
    real(wp) :: target
    integer :: i,i1,i2,i3,i4
    logical :: ok

    iostatus = 1
    if (soluatoms < 1 .or. soluatoms > mol%nat) then
      call qcg_final_constraint_error(fname,0,'invalid solute atom count')
      return
    end if
    do i = 1,block%nkv
      kv = block%kv_list(i)
      select case (kv%key)
      case ('force constant')
        cycle
      case ('distance','bond')
        if (kv%na /= 3) then
          call qcg_final_constraint_error(fname,0,'distance requires two atoms and one numeric target')
          return
        end if
        i1 = 0
        i2 = 0
        target = 0.0_wp
        ok = qcg_final_integer_token(kv%value_rawa(1),i1)
        if (ok) ok = qcg_final_integer_token(kv%value_rawa(2),i2)
        if (ok) ok = qcg_final_real_token(kv%value_rawa(3),target)
        if (.not.ok .or. target <= 0.0_wp .or. .not.qcg_final_atoms_ok([i1,i2],soluatoms)) then
          call qcg_final_constraint_error(fname,0,'invalid numeric distance or non-solute atom')
          return
        end if
        call cons%bondconstraint(i1,i2,target*aatoau,force_constant)
      case ('angle')
        if (kv%na /= 4) then
          call qcg_final_constraint_error(fname,0,'angle requires three atoms and one numeric target')
          return
        end if
        i1 = 0
        i2 = 0
        i3 = 0
        target = 0.0_wp
        ok = qcg_final_integer_token(kv%value_rawa(1),i1)
        if (ok) ok = qcg_final_integer_token(kv%value_rawa(2),i2)
        if (ok) ok = qcg_final_integer_token(kv%value_rawa(3),i3)
        if (ok) ok = qcg_final_real_token(kv%value_rawa(4),target)
        if (.not.ok .or. .not.qcg_final_atoms_ok([i1,i2,i3],soluatoms)) then
          call qcg_final_constraint_error(fname,0,'invalid numeric angle or non-solute atom')
          return
        end if
        call cons%angleconstraint(i1,i2,i3,target,force_constant)
      case ('dihedral')
        if (kv%na /= 5) then
          call qcg_final_constraint_error(fname,0,'dihedral requires four atoms and one numeric target')
          return
        end if
        i1 = 0
        i2 = 0
        i3 = 0
        i4 = 0
        target = 0.0_wp
        ok = qcg_final_integer_token(kv%value_rawa(1),i1)
        if (ok) ok = qcg_final_integer_token(kv%value_rawa(2),i2)
        if (ok) ok = qcg_final_integer_token(kv%value_rawa(3),i3)
        if (ok) ok = qcg_final_integer_token(kv%value_rawa(4),i4)
        if (ok) ok = qcg_final_real_token(kv%value_rawa(5),target)
        if (.not.ok .or. .not.qcg_final_atoms_ok([i1,i2,i3,i4],soluatoms)) then
          call qcg_final_constraint_error(fname,0,'invalid numeric dihedral or non-solute atom')
          return
        end if
        call cons%dihedralconstraint(i1,i2,i3,i4,target,force_constant)
      end select
      call calc%add(cons)
    end do
    iostatus = 0
  end subroutine build_qcg_final_constraints

!========================================================================================!

  logical function qcg_final_atoms_ok(atoms,soluatoms)
    implicit none
    integer,intent(in) :: atoms(:),soluatoms
    integer :: i,j

    qcg_final_atoms_ok = all(atoms >= 1 .and. atoms <= soluatoms)
    if (.not.qcg_final_atoms_ok) return
    do i = 1,size(atoms)-1
      do j = i+1,size(atoms)
        if (atoms(i) == atoms(j)) then
          qcg_final_atoms_ok = .false.
          return
        end if
      end do
    end do
  end function qcg_final_atoms_ok

!========================================================================================!

  logical function qcg_final_integer_token(token,value)
    implicit none
    character(len=*),intent(in) :: token
    integer,intent(out) :: value
    character(len=:),allocatable :: text
    integer :: io

    value = 0
    qcg_final_integer_token = .false.
    if (len_trim(token) == 0 .or. scan(trim(token),' '//achar(9)) /= 0) return
    text = trim(token)
    read (text,*,iostat=io) value
    qcg_final_integer_token = (io == 0)
  end function qcg_final_integer_token

!========================================================================================!

  logical function qcg_final_real_token(token,value)
    implicit none
    character(len=*),intent(in) :: token
    real(wp),intent(out) :: value
    character(len=:),allocatable :: text
    integer :: io

    value = 0.0_wp
    qcg_final_real_token = .false.
    if (len_trim(token) == 0 .or. scan(trim(token),' '//achar(9)) /= 0) return
    text = trim(token)
    read (text,*,iostat=io) value
    qcg_final_real_token = (io == 0 .and. ieee_is_finite(value))
  end function qcg_final_real_token

!========================================================================================!

  subroutine get_xtb_constraint_block(calc,mol,blk)
!********************************************************************
!* This is the fallback reader for xtb input files to set up a dict
!********************************************************************
    implicit none
    !> IN/OUTPUT
    type(calcdata),intent(inout) :: calc
    type(coord),intent(in) :: mol
    type(datablock),intent(in),target :: blk
    !> LOCAL
    integer :: i,j,k,io
    type(keyvalue),pointer :: kv
    real(wp) :: force_constant,dist,angl
    real(wp) :: rdum
    type(coord) :: molref
    logical :: useref
    logical,allocatable :: pairwise(:)
    logical,allocatable :: atlist(:)
    integer :: i1,i2,i3,i4,atm1,atm2
    real(wp) :: dum1,dum2,dum3,dum4
    type(constraint) :: cons
    type(constraint),allocatable :: conslist(:)

    useref = .false.
!>--- a default xtb force constant (in Eh), must be read first, if present
    force_constant = 0.05
    do i = 1,blk%nkv
      kv => blk%kv_list(i)
      select case (kv%key)

      case ('force constant')
        read (kv%rawvalue,*,iostat=io) rdum
        if (io == 0) then
          if (debug) write (stdout,'(a,a,a)') 'read force constant: ',to_str(rdum),' Eh'
          force_constant = rdum
        end if

      case ('reference')
        !> a reference geometry (must be the same molecule as the input)
        call molref%open(kv%rawvalue)
        if (any(mol%at(:) .ne. molref%at(:))) then
          write (stdout,'(a,/,a)') '**ERROR** while reading xtb-style input:',&
          & '  Geometry provided as "reference=" appears not to be the same molecule as CREST input!'
          error stop
        end if
        useref = .true.
        if (debug) write (stdout,'(a,a,a)') '> Using reference geometry "',kv%rawvalue,'"'

      end select
    end do

!>--- then the common constraints: distance, angle, dihedral
    do i = 1,blk%nkv
      kv => blk%kv_list(i)
      call get_xtb_rawa(kv,kv%rawvalue,io)
      select case (kv%key)
      case ('force constant','reference')
        !> already read above

      case ('distance','bond')
        if (kv%na .eq. 3.or.kv%na .eq. 4) then
          read (kv%value_rawa(1),*,iostat=io) i1
          if (io == 0) read (kv%value_rawa(2),*,iostat=io) i2
          if (io == 0) then
            if (trim(kv%value_rawa(3)) .eq. 'auto') then
              if (useref) then
                dist = molref%dist(i1,i2)
              else
                dist = mol%dist(i1,i2)
              end if
            else
              read (kv%value_rawa(3),*,iostat=io) dist
              dist = dist*aatoau
            end if
            !if(io == 0 .and. kv%na == 4)then
            !  read (kv%value_rawa(3),*,iostat=io) rdum
            !endif
            if (io == 0) then
              call cons%deallocate()
              call cons%bondconstraint(i1,i2,dist,force_constant)
              if (debug) call cons%print(stdout)
              call calc%add(cons)
            end if
          end if
        end if

      case ('angle')
        if (kv%na .eq. 4) then
          read (kv%value_rawa(1),*,iostat=io) i1
          if (io == 0) read (kv%value_rawa(2),*,iostat=io) i2
          if (io == 0) read (kv%value_rawa(3),*,iostat=io) i3
          if (io == 0) then
            if (trim(kv%value_rawa(4)) .eq. 'auto') then
              if (useref) then
                angl = molref%angle(i1,i2,i3)*radtodeg
              else
                angl = mol%angle(i1,i2,i3)*radtodeg
              end if
            else
              read (kv%value_rawa(4),*) angl
            end if
            call cons%deallocate()
            call cons%angleconstraint(i1,i2,i3,angl,force_constant)
            if (debug) call cons%print(stdout)
            call calc%add(cons)
          end if
        end if

      case ('dihedral')
        if (kv%na .eq. 5) then
          read (kv%value_rawa(1),*,iostat=io) i1
          if (io == 0) read (kv%value_rawa(2),*,iostat=io) i2
          if (io == 0) read (kv%value_rawa(3),*,iostat=io) i3
          if (io == 0) read (kv%value_rawa(4),*,iostat=io) i4
          if (io == 0) then
            if (trim(kv%value_rawa(5)) .eq. 'auto') then
              if (useref) then
                angl = molref%dihedral(i1,i2,i3,i4)*radtodeg
              else
                angl = mol%dihedral(i1,i2,i3,i4)*radtodeg
              end if
            else
              read (kv%value_rawa(5),*) angl
            end if
            call cons%deallocate()
            call cons%dihedralconstraint(i1,i2,i3,i4,angl,force_constant)
            if (debug) call cons%print(stdout)
            call calc%add(cons)
          end if
        end if

      case ('bondrange')
        read (kv%value_rawa(1),*,iostat=io) atm1
        if (io == 0) read (kv%value_rawa(2),*,iostat=io) atm2
        if (io == 0) read (kv%value_rawa(3),*,iostat=io) dum1
        if (io == 0) then
          dum1 = dum1*aatoau
          dum1 = max(0.0_wp,dum1) !> can't be negative
          select case (kv%na)
          case (3)
            dum2 = huge(dum2)/3.0_wp !> some huge value
            call cons%bondrangeconstraint(atm1,atm2,dum1,dum2)
          case (4)
            if (io == 0) read (kv%value_rawa(4),*,iostat=io) dum2
            dum2 = dum2*aatoau
            call cons%bondrangeconstraint(atm1,atm2,dum1,dum2)
          case (5)
            if (io == 0) read (kv%value_rawa(5),*,iostat=io) dum3
            call cons%bondrangeconstraint(atm1,atm2,dum1,dum2,beta=dum3)
          case (6)
            if (io == 0) read (kv%value_rawa(6),*,iostat=io) dum4
            call cons%bondrangeconstraint(atm1,atm2,dum1,dum2,beta=dum3,T=dum4)
          case default
            error stop '**ERROR** wrong number of arguments in bondrange constraint'
          end select
          call calc%add(cons)
          if (debug) call cons%print(stdout)
        end if

      case ('atoms')
        if (.not.allocated(pairwise)) allocate (pairwise(mol%nat),source=.false.)
        call get_atlist(mol%nat,atlist,kv%rawvalue,mol%at)
        do j = 1,mol%nat
          if (atlist(j)) pairwise(j) = .true.
        end do

      case ('elements')
        if (.not.allocated(pairwise)) allocate (pairwise(mol%nat),source=.false.)
        if (kv%id == valuetypes%raw_array) then
          do j = 1,kv%na
            i1 = e2i(kv%value_rawa(j))
            do k = 1,mol%nat
              if (i1 == mol%at(k)) pairwise(k) = .true.
            end do
          end do
        else
          i1 = e2i(kv%rawvalue)
          do j = 1,mol%nat
            if (i1 == mol%at(j)) pairwise(j) = .true.
          end do
        end if

      case default
        write (stdout,'(a,a,a)') 'xtb-style input key: "',kv%key,'" not defined for CREST'

      end select
    end do

!>--- if the pairwise section was allocated, set the distance constraints up here
    if (allocated(pairwise)) then
!>--- to reduce overhead, we allocate all of these constraints at once
      k = 0
      do i = 1,mol%nat
        do j = 1,i-1
          if (pairwise(i).and.pairwise(j)) k = k+1
        end do
      end do
      allocate (conslist(k))
      k = 0
      do i = 1,mol%nat
        do j = 1,i-1
          if (pairwise(i).and.pairwise(j)) then
            if (useref) then
              dist = molref%dist(j,i)
            else
              dist = mol%dist(j,i)
            end if
            k = k+1
            !call cons%deallocate()
            call conslist(k)%bondconstraint(j,i,dist,force_constant)
            if (debug) call conslist(k)%print(stdout)
          end if
        end do
      end do
      call calc%add(k,conslist)
      deallocate (conslist)
      deallocate (pairwise)
    end if
  end subroutine get_xtb_constraint_block

  subroutine get_xtb_wall_block(calc,mol,potscal,blk)
!**************************************
!* This is a reader for the $wall block
!***************************************
    implicit none
    !> IN/OUTPUT
    type(calcdata),intent(inout) :: calc
    type(coord),intent(in) :: mol
    real(wp),intent(inout) :: potscal
    type(datablock),intent(in),target :: blk
    !> LOCAL
    integer :: i,j,k,io
    type(keyvalue),pointer :: kv
    real(wp) :: force_constant,dist,angl
    real(wp) :: T,alpha,beta
    real(wp) :: rdum,rabc(3),r1,r2,r3
    logical,allocatable :: atlist(:)
    integer :: i1,i2,i3,i4
    integer :: pot
    type(constraint) :: cons

    if (debug) write (*,*) 'parsing $wall block'

!>--- asome defaults
    force_constant = 1.0_wp
    alpha = 30
    beta = 6.0_wp
    T = 300.0_wp
    pot = 1 !> 1= polynomial, 2= logfermi

!>--- get the parameters first
    do i = 1,blk%nkv
      kv => blk%kv_list(i)
      select case (kv%key)
      case ('force constant')
        !> already read above
        read (kv%rawvalue,*,iostat=io) rdum
        if (io == 0) force_constant = rdum

      case ('potential')
        if (trim(kv%rawvalue) .eq. 'logfermi') then
          pot = 2
        else
          pot = 1
        end if

      case ('alpha')
        read (kv%rawvalue,*,iostat=io) i1
        if (io == 0) alpha = i1

      case ('beta')
        read (kv%rawvalue,*,iostat=io) i1
        if (io == 0) beta = i1

      case ('temp')
        read (kv%rawvalue,*,iostat=io) i1
        if (io == 0) T = i1

      end select
    end do

!>--- create the potentials
    do i = 1,blk%nkv
      kv => blk%kv_list(i)
      call get_xtb_rawa(kv,kv%rawvalue,io)
      select case (kv%key)
      case ('force constant','potential','alpha','beta','temp')
        !> created in higher prio loop already

      case ('sphere')
        !> the sphere constraint si technically identical to the ellipsoid one, but
        !> with equal axis lengths in all 3 directions
        if (kv%na > 0) then
          if (trim(kv%value_rawa(1)) .eq. 'auto') then
            !> determine sphere
            call wallpot_core(mol,rabc,potscal=potscal)
            rdum = maxval(rabc(:))
            rabc(:) = rdum
          else
            read (kv%rawvalue,*,iostat=io) rdum
            if (io == 0) rabc(:) = rdum
          end if
          call get_atlist(mol%nat,atlist,kv%rawvalue,mol%at)
          call cons%deallocate()
          select case (pot)
          case (1) !> polynomial
            call cons%ellipsoid(mol%nat,atlist,rabc,force_constant,alpha,.false.)
          case (2) !> logfermi
            call cons%ellipsoid(mol%nat,atlist,rabc,T,beta,.true.)
          end select
          if (debug) call cons%print(stdout)
          call calc%add(cons)
        end if

      case ('ellipsoid')
        if (debug) write (*,*) 'parsing ellipsoid',kv%na
        if (kv%na > 0) then
          if (trim(kv%value_rawa(1)) .eq. 'auto') then
            !> determine ellipsoid
            call wallpot_core(mol,rabc,potscal=potscal)
          else
            read (kv%value_rawa(1),*,iostat=io) r1
            if (io == 0) read (kv%value_rawa(2),*,iostat=io) r2
            if (io == 0) read (kv%value_rawa(3),*,iostat=io) r3
            if (io == 0) then
              rabc(1) = r1
              rabc(2) = r2
              rabc(3) = r3
            end if
          end if
          call get_atlist(mol%nat,atlist,kv%rawvalue,mol%at)
          call cons%deallocate()
          select case (pot)
          case (1) !> polynomial
            call cons%ellipsoid(mol%nat,atlist,rabc,force_constant,alpha,.false.)
          case (2) !> logfermi
            call cons%ellipsoid(mol%nat,atlist,rabc,T,beta,.true.)
          end select
          if (debug) call cons%print(stdout)
          call calc%add(cons)
        end if

      case default
        write (stdout,'(a,a,a)') 'xtb-style input key: "',kv%key,'" not defined for CREST'

      end select
    end do
  end subroutine get_xtb_wall_block

  subroutine get_xtb_fix_block(calc,mol,blk)
!**************************************
!* This is a reader for the $fix block
!***************************************
    implicit none
    !> IN/OUTPUT
    type(calcdata),intent(inout) :: calc
    type(coord),intent(in) :: mol
    type(datablock),intent(in),target :: blk
    !> LOCAL
    integer :: i,j,k,io
    type(keyvalue),pointer :: kv
    real(wp) :: force_constant,dist,angl
    real(wp) :: T,alpha,beta
    real(wp) :: rdum,rabc(3),r1,r2,r3
    logical,allocatable :: pairwise(:)
    logical,allocatable :: atlist(:)
    integer :: i1,i2,i3,i4
    integer :: pot

!>--- get the parameters first
    do i = 1,blk%nkv
      kv => blk%kv_list(i)
      call get_xtb_rawa(kv,kv%rawvalue,io)
      select case (kv%key)

      case ('atoms')
        !> define frozen atoms via indices
        if (.not.allocated(pairwise)) allocate (pairwise(mol%nat),source=.false.)
        call get_atlist(mol%nat,atlist,kv%rawvalue,mol%at)
        do j = 1,mol%nat
          if (atlist(j)) pairwise(j) = .true.
        end do

      case ('elements')
        !> define frozen atoms via elements
        if (.not.allocated(pairwise)) allocate (pairwise(mol%nat),source=.false.)
        if (kv%id == valuetypes%raw_array) then
          do j = 1,kv%na
            i1 = e2i(kv%value_rawa(j))
            do k = 1,mol%nat
              if (i1 == mol%at(k)) pairwise(k) = .true.
            end do
          end do
        else
          i1 = e2i(kv%rawvalue)
          do j = 1,mol%nat
            if (i1 == mol%at(j)) pairwise(j) = .true.
          end do
        end if

      case default
        write (stdout,'(a,a,a)') 'xtb-style input key: "',kv%key,'" not defined for CREST'

      end select
    end do

    if (allocated(pairwise)) then
      i1 = count(pairwise)
      calc%nfreeze = i1
      if (debug) then
        write (stdout,'("> ",a)') 'Frozen atoms:'
        do i = 1,mol%nat
          if (pairwise(i)) write (stdout,'(1x,i0)',advance='no') i
        end do
        write (stdout,*)
      end if
      call move_alloc(pairwise,calc%freezelist)
    end if
  end subroutine get_xtb_fix_block

  subroutine get_xtb_metadyn_block(calc,mol,mtd_kscal,includeRMSD,rednat,blk)
!**************************************
!* This is a reader for the $metadyn block
!***************************************
    implicit none
    !> IN/OUTPUT
    type(calcdata),intent(inout) :: calc
    type(coord),intent(in) :: mol
    real(wp),intent(inout) :: mtd_kscal
    integer,allocatable,intent(inout) :: includeRMSD(:)
    integer,intent(inout) :: rednat
    type(datablock),intent(in),target :: blk
    !> LOCAL
    integer :: i,j,k,io
    type(keyvalue),pointer :: kv
    real(wp) :: force_constant,dist,angl
    real(wp) :: T,alpha,beta
    real(wp) :: rdum,rabc(3),r1,r2,r3
    logical,allocatable :: pairwise(:)
    logical,allocatable :: atlist(:)
    integer :: i1,i2,i3,i4
    integer :: pot

!>--- get the parameters first
    do i = 1,blk%nkv
      kv => blk%kv_list(i)
      call get_xtb_rawa(kv,kv%rawvalue,io)
      select case (kv%key)

      case ('atoms')
        !> define atoms in metadynamics via indices
        if (.not.allocated(pairwise)) allocate (pairwise(mol%nat),source=.false.)
        call get_atlist(mol%nat,atlist,kv%rawvalue,mol%at)
        do j = 1,mol%nat
          if (atlist(j)) pairwise(j) = .true.
        end do

      case ('elements')
        !> define atoms in metadynamics via elements
        if (.not.allocated(pairwise)) allocate (pairwise(mol%nat),source=.false.)
        if (kv%id == valuetypes%raw_array) then
          do j = 1,kv%na
            i1 = e2i(kv%value_rawa(j))
            do k = 1,mol%nat
              if (i1 == mol%at(k)) pairwise(k) = .true.
            end do
          end do
        else
          i1 = e2i(kv%rawvalue)
          do j = 1,mol%nat
            if (i1 == mol%at(j)) pairwise(j) = .true.
          end do
        end if

      case ('kscal')
        !> define a global metadynamics k-push scaling factor
        read (kv%rawvalue,*) r1
        mtd_kscal = r1

      case default
        write (stdout,'(a,a,a)') 'xtb-style input key: "',kv%key,'" not defined for CREST'

      end select
    end do

    if (allocated(pairwise)) then
      i1 = count(pairwise)
      if (debug) then
        write (stdout,'("> ",a)') 'Metadynamics atoms:'
        do i = 1,mol%nat
          if (pairwise(i)) write (stdout,'(1x,i0)',advance='no') i
        end do
        write (stdout,*)
      end if
      if (.not.allocated(includeRMSD)) allocate (includeRMSD(mol%nat),source=0)
      do i = 1,mol%nat
        if (pairwise(i)) includeRMSD(i) = 1
      end do
      rednat = i1
    end if

    call mol%deallocate()
  end subroutine get_xtb_metadyn_block

!========================================================================================!

  subroutine parse_xtb_input_fallback(fname,dict)
!********************************************************************
!* This is the fallback reader for xtb input files to set up a dict
!********************************************************************
    implicit none

    character(len=*) :: fname !> name of the input file
    type(root_object),intent(out) :: dict
    type(filetype) :: file
    integer :: i,j,k,io
    logical :: get_root_kv
    type(keyvalue) :: kvdum
    type(datablock) :: blkdum

    call dict%new()
!>--- open file to read and remove comments
    call file%open(trim(fname))
    dict%filename = trim(file%filename)
    call remove_comments(file)

!>--- all valid key-values must be in $-blocks, no root-level ones
    get_root_kv = .false.
!>--- the loop where the input file is read
    do i = 1,file%nlines
      if (file%current_line > i) cycle
      !> key-value pairs of the root dict (ignored for xtb)
      if (get_root_kv) then
        call get_keyvalue(kvdum,file%line(i),io)
        if (io == 0) then
          call dict%addkv(kvdum) !> add to dict
        end if
      end if

      !> the $-blocks
      if (isxtbheader(file%line(i))) then
        get_root_kv = .false.
        call read_xtbdatablock(file,i,blkdum)
        call dict%addblk(blkdum) !> add to dict
      end if
    end do

    call file%close()

    return
  end subroutine parse_xtb_input_fallback
!========================================================================================!
  subroutine remove_comments(file)
    use filemod
    implicit none
    type(filetype) :: file
    character(len=1),parameter :: com = '#'
    integer :: i
    do i = 1,file%nlines
      call clearcomment(file%f(i),com)
      call clearcomment(file%f(i),"$end")
    end do
  end subroutine remove_comments

  function isxtbheader(str)
    implicit none
    logical :: isxtbheader
    character(len=*) :: str
    character(len=:),allocatable :: atmp
    integer :: l
    isxtbheader = .false.
    atmp = adjustl(trim(str))
    l = len_trim(atmp)
    if (l < 1) return
    if ((atmp(1:1) == '$')) then
      isxtbheader = .true.
    end if
    return
  end function isxtbheader

!========================================================================================!

  subroutine read_xtbdatablock(file,i,blk)
    implicit none
    type(filetype),intent(inout)  :: file
    type(datablock),intent(inout) :: blk
    integer,intent(in) :: i

    character(len=:),allocatable :: rawline
    type(keyvalue) :: kvdum
    integer :: j,k,io

    call blk%deallocate()

    blk%header = file%line(i)
    call clearxtbheader(blk%header)

    do j = i+1,file%nlines
      rawline = file%line(j)
      if (isxtbheader(rawline)) exit
      call get_xtb_keyvalue(kvdum,rawline,io)
      if (io == 0) then
        call blk%addkv(kvdum)
      end if
    end do

  end subroutine read_xtbdatablock

!========================================================================================!

  subroutine get_xtb_keyvalue(kv,str,io)
    implicit none
    class(keyvalue),intent(inout) :: kv
    character(len=*) :: str
    integer,intent(out) :: io
    character(len=:),allocatable :: tmpstr
    character(len=:),allocatable :: tmpstr_rc
    character(len=:),allocatable :: ktmp
    character(len=:),allocatable :: vtmp
    integer :: i,j,k,na,plast
    integer :: l(3)
    call kv%deallocate()
    io = 0
    tmpstr = adjustl(lowercase(str))
    tmpstr_rc = adjustl(trim(str))

    !> key-value conditions
    l(1) = index(tmpstr,'=')
    l(2) = index(tmpstr,':')
    l(3) = index(tmpstr,' ')

    k = 0
    if (l(1) .ne. 0) then
      k = l(1)
    else if (l(2) .ne. 0) then
      k = l(2)
    else if (l(3) .ne. 0) then
      k = l(3)
    end if

    if (k .eq. 0) then
      io = -1
      return
    end if

    ktmp = trim(adjustl(tmpstr(:k-1)))
    vtmp = trim(adjustl(tmpstr_rc(k+1:)))
    kv%key = ktmp !> the key as string
    kv%rawvalue = vtmp !> value as unformatted string

    !> comma denotes an array of strings
    k = index(vtmp,',')
    if (k .ne. 0) then
      kv%id = valuetypes%raw_array
      j = len_trim(vtmp)
      na = 1
      !> count elements
      do i = 1,j
        if (vtmp(i:i) .eq. ',') na = na+1
      end do
      !> allocate
      kv%na = na
      allocate (kv%value_rawa(na),source=repeat(' ',j))
      plast = 1
      na = 1
      do i = 1,j
        if (na == kv%na) then !> for the last argument
          kv%value_rawa(na) = trim(adjustl(vtmp(plast:)))
          exit
        end if
        if (vtmp(i:i) .eq. ',') then
          kv%value_rawa(na) = trim(adjustl(vtmp(plast:i-1)))
          plast = i+1
          na = na+1
        end if
      end do
    end if
  end subroutine get_xtb_keyvalue

  subroutine get_xtb_rawa(kv,str,io)
    implicit none
    class(keyvalue),intent(inout) :: kv
    character(len=*) :: str
    integer,intent(out) :: io
    character(len=:),allocatable :: ktmp
    character(len=:),allocatable :: vtmp
    integer :: i,j,k,na,plast
    integer :: l(3)

    io = 0
    if (allocated(kv%value_rawa)) deallocate (kv%value_rawa)

    vtmp = trim(adjustl(str))

    !> comma denotes an array of strings
    k = index(vtmp,',')
    if (k .ne. 0) then
      j = len_trim(vtmp)
      na = 1
      !> count elements
      do i = 1,j
        if (vtmp(i:i) .eq. ',') na = na+1
      end do
      !> allocate
      kv%na = na
      allocate (kv%value_rawa(na),source=repeat(' ',j))
      plast = 1
      na = 1
      do i = 1,j
        if (na == kv%na) then !> for the last argument
          kv%value_rawa(na) = trim(adjustl(vtmp(plast:)))
          exit
        end if
        if (vtmp(i:i) .eq. ',') then
          kv%value_rawa(na) = trim(adjustl(vtmp(plast:i-1)))
          plast = i+1
          na = na+1
        end if
      end do
    end if
  end subroutine get_xtb_rawa

!========================================================================================!
!> for given input file parse the next block
  subroutine parse_xtbinfile_block(file,i,rawblk)
    implicit none
    type(filetype),intent(inout)      :: file
    type(parseblock),intent(inout) :: rawblk
    integer,intent(in) :: i
    logical :: saveblock
    integer :: j,k,l
    character(len=:),allocatable :: src

    call rawblk%deallocate()

    src = repeat(' ',file%lwidth)

    if (isxtbheader(file%line(i))) then
      saveblock = .true.
      rawblk%header = file%line(i)
      !      cycle
    end if
    !> get blocklength
    k = i+1
    l = 0
    jloop: do j = k,file%nlines
      if (isxtbheader(file%line(j))) then
        file%current_line = j
        exit jloop
      end if
      if (len_trim(file%line(j)) > 0) then
        l = l+1
      end if
      if (j == file%nlines) file%current_line = j
    end do jloop
    !if (l < 1) exit iloop
    if (l < 1) return
    !> get block
    rawblk%len = l
    allocate (rawblk%content(l),source=src)
    l = 0
    jloop2: do j = k,file%nlines
      if (isheader(file%line(j))) then
        saveblock = .false.
        return
      end if
      if (len_trim(file%line(j)) > 0) then
        l = l+1
        rawblk%content(l) = file%line(j)
      end if
    end do jloop2
    !end do iloop

    return
  end subroutine parse_xtbinfile_block

!=======================================================================================!

  subroutine clearxtbheader(hdr)
    implicit none
    character(len=*) :: hdr
    integer :: i,k,l
    character(len=:),allocatable :: atmp,btmp
    character(len=1) :: s
    atmp = adjustl(hdr)
    atmp = trim(atmp)
    !>remove whitespaces
    l = len_trim(atmp)
    k = index(hdr,'$')
    if (k > 0) then
      atmp(k:k) = ' '
      atmp = adjustl(atmp)
    end if
    hdr = trim(atmp)
    return
  end subroutine clearxtbheader

!============================================================================!

  subroutine parse_constraints_from_cts(calc,mol,cts)
!*********************************************
!* Routine for parsing cts objects into calcdata
!*********************************************
    implicit none
    !> IN/OUTPUT
    type(calcdata),intent(inout) :: calc
    class(coord),intent(inout) :: mol   !> polymorphic class(!) to use in qcg
    type(legacy_constraints),intent(in) :: cts
    !> LOCAL
    type(root_object),allocatable,target :: dict
    type(datablock),pointer :: blk
    logical :: ex
    character(len=:),allocatable :: hdr
    integer :: i,j,k,l
    !> some defaults/fallbacks
    real(wp) :: potscal = 1.0_wp
    integer :: rednat
    integer,allocatable :: includeRMSD(:)
    real(wp) :: mtd_kscal

    allocate (dict)
    !call parse_xtb_input_fallback(fname,dict)
    call parse_cts_internal(cts,dict)
    !call dict%print()

    !write (stdout,'(a,a,a)') 'Parsing xtb-type constraints from internal backup to set up calculators ...'
    !> iterate through the blocks and save the necessary information
    do i = 1,dict%nblk
      blk => dict%blk_list(i)
      hdr = trim(blk%header)
      select case (hdr)
      case ('constrain')
        call get_xtb_constraint_block(calc,mol,blk)
      case ('wall')
        call get_xtb_wall_block(calc,mol,potscal,blk)
      case ('fix')
        call get_xtb_fix_block(calc,mol,blk)
      case ('metadyn')
        call get_xtb_metadyn_block(calc,mol,mtd_kscal, &
        & includeRMSD,rednat,blk)
      case default
        write (stdout,'(a,a,a)') 'xtb-style input block: "$',trim(hdr),'" not defined for CREST'
      end select
    end do

    if (debug) stop
  end subroutine parse_constraints_from_cts

  subroutine parse_cts_internal(cts,dict)
!********************************************************************
!* This is the fallback reader for xtb constraints from cts to set up a dict
!********************************************************************
    implicit none
    !> IN/OUTPUT
    type(legacy_constraints),intent(in) :: cts
    type(root_object),intent(out) :: dict
    !> LOCAL
    type(filetype) :: file
    integer :: i,j,k,io,b
    logical :: get_root_kv
    type(keyvalue) :: kvdum
    type(datablock) :: blkdum
    character(len=:),allocatable :: dummy

    call dict%new()
!>--- parse cts into a "file" --> internal storage
    k = 0
    if (cts%used) then
      do i = 1,cts%ndim
        if (trim(cts%sett(i)) .ne. '') k = k+1
      end do
    end if
    if (cts%NCI.and.allocated(cts%pots)) then
      do i = 1,10
        if (trim(cts%pots(i)) .ne. '') k = k+1
      end do
    end if
    if (allocated(cts%cbonds)) then
      do i = 1,cts%n_cbonds
        if (trim(cts%cbonds(i)) .ne. '') k = k+1
      end do
    end if
    b = 128
    file%lwidth = b
    dummy = repeat(' ',b+5)
    file%nlines = k
    file%current_line = 1
    allocate (file%f(k),source=dummy)
    k=0
    if (cts%used) then
      do i = 1,cts%ndim
        if (trim(cts%sett(i)) .ne. '')then
          k = k+1
          file%f(k) = trim(cts%sett(i))
        endif
      end do
    end if
    if (cts%NCI.and.allocated(cts%pots)) then
      do i = 1,10
        if (trim(cts%pots(i)) .ne. '')then
          k = k+1
          file%f(k) = trim(cts%pots(i))
        endif
      end do
    end if
    if (allocated(cts%cbonds)) then
      do i = 1,cts%n_cbonds
        if (trim(cts%cbonds(i)) .ne. '')then
          k = k+1
          file%f(k) = trim(cts%cbonds(i))
        endif
      end do
    end if

    dict%filename = "internal cts"
    call remove_comments(file)

!>--- all valid key-values must be in $-blocks, no root-level ones
    get_root_kv = .false.
!>--- the loop where the input file is read
    do i = 1,file%nlines
      if (file%current_line > i) cycle
      !> key-value pairs of the root dict (ignored for xtb)
      if (get_root_kv) then
        call get_keyvalue(kvdum,file%line(i),io)
        if (io == 0) then
          call dict%addkv(kvdum) !> add to dict
        end if
      end if

      !> the $-blocks
      if (isxtbheader(file%line(i))) then
        get_root_kv = .false.
        call read_xtbdatablock(file,i,blkdum)
        call dict%addblk(blkdum) !> add to dict
      end if
    end do

    call file%close()

    return
  end subroutine parse_cts_internal

!========================================================================================!
end module parse_xtbinput
