/*
 *  This file is part of Netsukuku.
 *  (c) Copyright 2015 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */
using Gee;

namespace TaskletSystem
{
    public interface ITaskletSpawnable : Object
    {
        public abstract void * func();
    }

    public interface ITaskletHandle : Object
    {
        public abstract bool is_running();
        public abstract void kill();
        public abstract bool is_joinable();
        public abstract void * join();
    }

    public class TaskletCommandResult : Object
    {
        public string stdout;
        public string stderr;
        public int exit_status;
    }

    public interface IServerStreamSocket : Object
    {
        public abstract IConnectedStreamSocket accept() throws Error;
        public abstract void close() throws Error;
    }

    public interface IConnectedStreamSocket : Object
    {
        public abstract size_t recv(uint8* b, size_t maxlen) throws Error;
        public abstract size_t send_part(uint8* b, size_t len) throws Error;
        public void send(uint8* b, size_t len) throws Error
        {
            while (len > 0)
            {
                size_t done = send_part(b, len);
                b += done;
                len -= done;
            }
        }
        public abstract void close() throws Error;
    }

    public interface IServerDatagramSocket : Object
    {
        public abstract size_t recvfrom(uint8* b, size_t maxlen) throws Error;
        public abstract void close() throws Error;
    }

    public interface IClientDatagramSocket : Object
    {
        public abstract size_t sendto(uint8* b, size_t len) throws Error;
        public abstract void close() throws Error;
    }

    public interface IServerStreamNetworkSocket : Object, IServerStreamSocket
    {
    }

    public interface IConnectedStreamNetworkSocket : Object, IConnectedStreamSocket
    {
    }

    public interface IServerDatagramNetworkSocket : Object, IServerDatagramSocket
    {
    }

    public interface IClientDatagramNetworkSocket : Object, IClientDatagramSocket
    {
    }

    public interface IServerStreamLocalSocket : Object, IServerStreamSocket
    {
    }

    public interface IConnectedStreamLocalSocket : Object, IConnectedStreamSocket
    {
    }

    public interface IServerDatagramLocalSocket : Object, IServerDatagramSocket
    {
    }

    public interface IClientDatagramLocalSocket : Object, IClientDatagramSocket
    {
    }

    public errordomain ChannelError
    {
        TIMEOUT
    }

    public interface IChannel : Object
    {
        public abstract void send(Value v);
        public abstract void send_async(Value v);
        public abstract int get_balance();
        public abstract Value recv();
        public abstract Value recv_with_timeout(int timeout_msec) throws ChannelError;
    }

    public interface ITasklet : Object
    {
        public abstract void schedule();
        public abstract void ms_wait(int msec);
        [NoReturn]
        public abstract void exit_tasklet(void * ret=null);
        public abstract ITaskletHandle spawn(ITaskletSpawnable sp, bool joinable=false);

        public abstract TaskletCommandResult exec_command_argv(Gee.List<string> argv) throws Error;
        public TaskletCommandResult exec_command(string cmdline) throws Error
        {
            ArrayList<string> argv = new ArrayList<string>();
            argv.add_all_array(cmdline.split(" "));
            return exec_command_argv(argv);
        }

        public abstract size_t read(int fd, void* b, size_t maxlen) throws Error;
        public abstract size_t write(int fd, void* b, size_t count) throws Error;
        public abstract IServerStreamNetworkSocket get_server_stream_network_socket(string my_addr, uint16 my_tcp_port) throws Error;
        public abstract IConnectedStreamNetworkSocket get_client_stream_network_socket(string dest_addr, uint16 dest_tcp_port) throws Error;
        public abstract IServerDatagramNetworkSocket get_server_datagram_network_socket(uint16 udp_port, string my_dev) throws Error;
        public abstract IClientDatagramNetworkSocket get_client_datagram_network_socket(uint16 udp_port, string my_dev) throws Error;
        public abstract IServerStreamLocalSocket get_server_stream_local_socket(string listen_pathname) throws Error;
        public abstract IConnectedStreamLocalSocket get_client_stream_local_socket(string send_pathname) throws Error;
        public abstract IServerDatagramLocalSocket get_server_datagram_local_socket(string listen_pathname) throws Error;
        public abstract IClientDatagramLocalSocket get_client_datagram_local_socket(string send_pathname) throws Error;

        public abstract IChannel get_channel();

        public DispatchableTasklet create_dispatchable_tasklet() {return new DispatchableTasklet(this);}
    }

    public class DispatchableTasklet
    {
        private class DispatchedTasklet : Object
        {
            public IChannel ch_end;
            public IChannel ch_start;
            public ITaskletSpawnable sp;
            public DispatchedTasklet(ITaskletSpawnable sp, IChannel ch_end, IChannel ch_start)
            {
                this.ch_end = ch_end;
                this.ch_start = ch_start;
                this.sp = sp;
            }
        }
        private class DispatcherTasklet : Object, ITaskletSpawnable
        {
            public DispatchableTasklet dsp;
            public void * func()
            {
                while (dsp.lst_sp.size > 0)
                {
                    DispatchedTasklet x = dsp.lst_sp.remove_at(0);
                    if (x.ch_start.get_balance() < 0) x.ch_start.send_async(0);
                    x.sp.func();
                    if (x.ch_end.get_balance() < 0) x.ch_end.send_async(0);
                }
                return null;
            }
        }
        private ITaskletHandle? t;
        private ArrayList<DispatchedTasklet> lst_sp;
        private ITasklet tasklet;
        internal DispatchableTasklet(ITasklet tasklet)
        {
            this.tasklet = tasklet;
            t = null;
            lst_sp = new ArrayList<DispatchedTasklet>();
        }
        public void dispatch(ITaskletSpawnable sp, bool wait_end=false, bool wait_start=false)
        {
            DispatchedTasklet dt = new DispatchedTasklet(sp, tasklet.get_channel(), tasklet.get_channel());
            lst_sp.add(dt);
            if (t == null || !t.is_running())
            {
                DispatcherTasklet ts = new DispatcherTasklet();
                ts.dsp = this;
                t = tasklet.spawn(ts);
            }
            if (wait_end)
            {
                dt.ch_end.recv();
            }
            else if (wait_start)
            {
                dt.ch_start.recv();
            }
        }
        public bool is_empty()
        {
            return t == null || !t.is_running();
        }
    }
}

